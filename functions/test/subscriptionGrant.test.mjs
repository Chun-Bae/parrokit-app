// 매달 주는 구독 패롯을 얼마나, 어떤 키로 주는지. 쓸 때 어디서 깎는지.
//
// 실행: functions에서 `npm run test:subgrant`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {
  grantForTier,
  grantKey,
  expireKey,
  shouldGrant,
  grantAmountFor,
  grantedFrom,
  DEFAULT_GRANTS,
} = require("../lib/subscriptionGrant.js");
const {splitParrotSpend} = require("../lib/wallet.js");

test("매달 주는 양은 라이트 100, 프로 400, 무료 0", () => {
  assert.deepEqual(DEFAULT_GRANTS, {
    free: 0,
    light: 100,
    plus: 250,
    pro: 400,
    max: 700,
  });
  assert.equal(grantForTier("max"), 700);
  assert.equal(grantForTier("light"), 100);
  assert.equal(grantForTier("pro"), 400);
  assert.equal(grantForTier("free"), 0);
});

test("설정값이 기본값을 이기고, 이상한 값은 버린다", () => {
  assert.equal(grantForTier("light", {light: 150}), 150);
  assert.equal(grantForTier("pro", {pro: -1}), 400);
  assert.equal(grantForTier("pro", {light: 150}), 400);
});

test("장부 키는 단계와 기간으로 갈린다", () => {
  assert.equal(grantKey("light", 1764000000000), "sub_grant_light_1764000000000");
  assert.notEqual(grantKey("light", 1), grantKey("light", 2), "기간이 다르면 다른 키");
  assert.notEqual(grantKey("light", 1), grantKey("pro", 1), "단계가 다르면 다른 키");
  assert.equal(grantKey("pro", null), "sub_grant_pro_unknown");
  assert.equal(expireKey(1764000000000), "sub_expire_1764000000000");
});

test("끝난 구독과 무료에는 주지 않는다", () => {
  assert.equal(shouldGrant({tier: "light", status: "active"}), true);
  assert.equal(shouldGrant({tier: "pro", status: "grace"}), true);
  assert.equal(
    shouldGrant({tier: "light", status: "canceled"}),
    true,
    "해지를 예약해도 남은 기간 몫은 준다"
  );
  assert.equal(shouldGrant({tier: "pro", status: "expired"}), false);
  assert.equal(shouldGrant({tier: "free", status: "active"}), false);
});

test("쓸 때는 구독 패롯부터 깎는다", () => {
  assert.deepEqual(splitParrotSpend(100, -30), {sub: -30, normal: 0});
  assert.deepEqual(
    splitParrotSpend(20, -30),
    {sub: -20, normal: -10},
    "모자라면 나머지는 보통 패롯에서"
  );
  assert.deepEqual(splitParrotSpend(0, -30), {sub: 0, normal: -30});
});

test("넣는 것은 보통 패롯으로 간다", () => {
  assert.deepEqual(splitParrotSpend(100, 50), {sub: 0, normal: 50});
  assert.deepEqual(splitParrotSpend(0, 0), {sub: 0, normal: 0});
});


// 기간 중에 단계를 올리면 차액만 준다(5차 530).
//
// 업그레이드하면 스토어가 남은 기간을 비례 환불하고 새 기간을 시작한다.
// 장부 키(tier+periodEnd)가 달라져 전액이 또 들어갔다 - 라이트(100) 뒤
// 프로로 올리면 500개, 한 단계씩 밟으면 1,450개까지 갔다.
const DAY = 24 * 60 * 60 * 1000;

test("처음 받는 사람은 전액", () => {
  assert.equal(grantAmountFor(400, null, 1000), 400);
});

test("기간이 한참 남았는데 올리면 차액만", () => {
  const now = 1_000_000_000_000;
  // 라이트로 100을 받았고 기간이 20일 남았다. 프로로 올린다.
  const granted = {amount: 100, periodEnd: now + 20 * DAY};
  assert.equal(grantAmountFor(400, granted, now), 300);
});

test("한 단계씩 밟아 올려도 합이 맥스 몫을 넘지 않는다", () => {
  const now = 1_000_000_000_000;
  const end = now + 20 * DAY;
  let total = 0;
  let granted = null;
  for (const full of [100, 250, 400, 700]) {
    const add = grantAmountFor(full, granted, now);
    total += add;
    granted = {amount: full, periodEnd: end};
  }
  assert.equal(total, 700);
});

test("정상 갱신이면 전액", () => {
  const now = 1_000_000_000_000;
  // 갱신 이벤트는 이전 기간이 끝나는 그 시각에 온다.
  assert.equal(grantAmountFor(400, {amount: 400, periodEnd: now}, now), 400);
  // 조금 늦게 와도 마찬가지.
  assert.equal(
    grantAmountFor(400, {amount: 400, periodEnd: now - 5000}, now),
    400
  );
});

test("시계가 조금 어긋나도 갱신은 깎지 않는다", () => {
  const now = 1_000_000_000_000;
  // 30초 차이는 갱신으로 본다(여유 1분).
  assert.equal(
    grantAmountFor(400, {amount: 400, periodEnd: now + 30_000}, now),
    400
  );
});

test("같은 단계로 기간 중에 또 와도 더 주지 않는다", () => {
  const now = 1_000_000_000_000;
  const granted = {amount: 400, periodEnd: now + 10 * DAY};
  assert.equal(grantAmountFor(400, granted, now), 0);
});

test("기간 끝을 모르면 전액", () => {
  assert.equal(grantAmountFor(400, {amount: 100, periodEnd: null}, 1000), 400);
});

test("저장된 맵에서 지급 기록을 읽는다", () => {
  assert.deepEqual(
    grantedFrom({tier: "light", grantedAmount: 100, grantedPeriodEnd: 55}),
    {amount: 100, periodEnd: 55}
  );
  // 예전 문서에는 없던 칸이다.
  assert.equal(grantedFrom({tier: "light"}), null);
  assert.equal(grantedFrom(null), null);
  assert.deepEqual(grantedFrom({grantedAmount: 100}), {
    amount: 100,
    periodEnd: null,
  });
});
