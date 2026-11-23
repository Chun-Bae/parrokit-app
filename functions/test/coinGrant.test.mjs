// 패롯 충전을 서버가 지급한다(5차 568).
//
// 전에는 앱이 결제 콜백에서 바로 Firestore에 패롯을 더했다. 영수증을
// 확인하는 곳이 없어서 결제 없이도 패롯이 생겼고, 패롯은 Whisper·Gemini·R2를
// 쓰는 값이라 그대로 서버 비용이 됐다.
//
// 실행: functions에서 `npm run test:coins`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {readFileSync} from "node:fs";

const require = createRequire(import.meta.url);
const {
  COIN_PACKAGES,
  coinsFor,
  coinPurchaseFromEvent,
  coinRefundFromEvent,
} = require("../lib/coinGrant.js");

const base = {
  id: "evt-coin-1",
  app_user_id: "uid-1",
  type: "NON_RENEWING_PURCHASE",
  product_id: "parrokit_coins_1",
  event_timestamp_ms: 1763000000000,
};

const event = (over = {}) => ({event: {...base, ...over}});

test("아는 상품은 표대로 준다", () => {
  assert.equal(coinsFor("parrokit_coins_1"), 88);
  assert.equal(coinsFor("parrokit_coins_10"), 880);
});

// 앱은 못 찾으면 첫 상품 기준으로 줬다. 그러면 RevenueCat에만 상품을
// 추가했을 때 낸 돈과 받는 패롯이 조용히 어긋난다.
test("모르는 상품은 주지 않는다", () => {
  assert.equal(coinsFor("parrokit_coins_999"), null);
  assert.equal(coinsFor(""), null);
});

test("충전 이벤트에서 줄 값을 뽑는다", () => {
  const purchase = coinPurchaseFromEvent(event());
  assert.equal(purchase.uid, "uid-1");
  assert.equal(purchase.productId, "parrokit_coins_1");
  assert.equal(purchase.coins, 88);
  assert.equal(purchase.eventId, "evt-coin-1");
});

test("구독 이벤트는 충전으로 보지 않는다", () => {
  assert.equal(coinPurchaseFromEvent(event({type: "RENEWAL"})), null);
  assert.equal(coinPurchaseFromEvent(event({type: "INITIAL_PURCHASE"})), null);
});

test("로그인 전 임시 id는 우리 계정이 아니다", () => {
  assert.equal(
    coinPurchaseFromEvent(event({app_user_id: "$RCAnonymousID:abc"})),
    null
  );
});

test("모르는 상품이면 지급 대상이 아니다", () => {
  assert.equal(coinPurchaseFromEvent(event({product_id: "something"})), null);
  assert.equal(coinPurchaseFromEvent(event({product_id: undefined})), null);
});

test("이벤트 id가 없으면 사람·상품·시각으로 만든다", () => {
  const purchase = coinPurchaseFromEvent(event({id: undefined}));
  assert.equal(
    purchase.eventId,
    "uid-1_parrokit_coins_1_1763000000000"
  );
});

test("본문이 엉뚱해도 던지지 않는다", () => {
  assert.equal(coinPurchaseFromEvent(null), null);
  assert.equal(coinPurchaseFromEvent({}), null);
  assert.equal(coinPurchaseFromEvent({event: "글"}), null);
});

// 값을 한쪽만 고치면 낸 돈과 받는 패롯이 어긋난다.
test("앱의 상품 표와 값이 같다", () => {
  const dart = readFileSync(
    "../lib/features/settings/more/data/coin_package.dart",
    "utf8"
  );
  const found = {};
  const re =
    /productId:\s*'([^']+)',\s*price:\s*\d+,\s*coins:\s*(\d+),\s*bonusCoins:\s*(\d+)/g;
  let m;
  while ((m = re.exec(dart)) !== null) {
    found[m[1]] = Number(m[2]) + Number(m[3]);
  }

  assert.ok(Object.keys(found).length > 0, "앱 표를 읽지 못했다");
  assert.deepEqual(found, COIN_PACKAGES);
});

// RevenueCat은 1회성 구매를 물러 줄 때도 REFUND를 보낸다. 그 타입은 구독
// allowlist에도 있어서, 가리지 않으면 충전 환불이 구독 경로로 흘러가
// 구독이 만료되고 subParrots까지 지워진다(5차 568).
test("충전 환불을 알아본다", () => {
  const refund = coinRefundFromEvent(
    event({type: "REFUND", id: "evt-refund-1"})
  );
  assert.equal(refund.uid, "uid-1");
  assert.equal(refund.productId, "parrokit_coins_1");
  assert.equal(refund.coins, 88);
  assert.equal(refund.eventId, "evt-refund-1");
});

test("구독 환불은 충전 환불이 아니다", () => {
  assert.equal(
    coinRefundFromEvent(
      event({type: "REFUND", product_id: "parrokit_sub_light_month"})
    ),
    null
  );
  // 상품 id가 아예 없는 환불도 구독 쪽이 맡는다.
  assert.equal(
    coinRefundFromEvent(event({type: "REFUND", product_id: undefined})),
    null
  );
});

test("환불이 아닌 이벤트는 회수 대상이 아니다", () => {
  assert.equal(coinRefundFromEvent(event()), null);
  assert.equal(coinRefundFromEvent(event({type: "RENEWAL"})), null);
});

test("충전과 환불은 서로를 삼키지 않는다", () => {
  const purchase = event();
  const refunded = event({type: "REFUND"});
  assert.notEqual(coinPurchaseFromEvent(purchase), null);
  assert.equal(coinRefundFromEvent(purchase), null);
  assert.equal(coinPurchaseFromEvent(refunded), null);
  assert.notEqual(coinRefundFromEvent(refunded), null);
});

test("환불 장부 키는 충전 키와 다르다", () => {
  // 같은 이벤트 id가 오더라도 넣은 것과 거둔 것이 한 칸을 쓰면 안 된다.
  const purchase = coinPurchaseFromEvent(event({id: "same"}));
  const refund = coinRefundFromEvent(event({type: "REFUND", id: "same"}));
  assert.equal(purchase.eventId, refund.eventId);
  // 키 앞머리는 coinGrant가 붙인다(coin_purchase_ / coin_refund_).
  const source = readFileSync("../functions/src/coinGrant.ts", "utf8");
  assert.ok(source.includes("`coin_purchase_${purchase.eventId}`"));
  assert.ok(source.includes("`coin_refund_${refund.eventId}`"));
});

test("웹훅이 환불을 충전·구독보다 먼저 가른다", () => {
  const handler = readFileSync("../functions/src/subscriptionEvent.ts", "utf8");
  const refundAt = handler.indexOf("coinRefundFromEvent(req.body)");
  const purchaseAt = handler.indexOf("coinPurchaseFromEvent(req.body)");
  const subAt = handler.indexOf("subscriptionFromEvent(req.body)");
  assert.ok(refundAt > 0 && purchaseAt > 0 && subAt > 0);
  assert.ok(refundAt < purchaseAt, "환불이 충전보다 먼저");
  assert.ok(purchaseAt < subAt, "충전이 구독보다 먼저");
});
