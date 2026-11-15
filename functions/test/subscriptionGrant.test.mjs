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
  DEFAULT_GRANTS,
} = require("../lib/subscriptionGrant.js");
const {splitParrotSpend} = require("../lib/wallet.js");

test("매달 주는 양은 라이트 100, 프로 400, 무료 0", () => {
  assert.deepEqual(DEFAULT_GRANTS, {free: 0, light: 100, pro: 400});
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
