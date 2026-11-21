// 서버가 단계를 어떻게 읽고, 단계별 한도를 어떻게 고르는지.
//
// 실행: functions에서 `npm run test:tier`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {
  tierFromUserDoc,
  limitForTier,
  sanitizeLimits,
  DEFAULT_ASSIST_LIMITS,
} = require("../lib/subscriptionTier.js");

test("서버에 적힌 단계를 그대로 읽는다", () => {
  assert.equal(
    tierFromUserDoc({subscription: {tier: "pro", status: "active"}}),
    "pro"
  );
  assert.equal(
    tierFromUserDoc({subscription: {tier: "light", status: "active"}}),
    "light"
  );
});

test("해지 예약과 결제 밀림은 기간 안이라 혜택을 그대로 준다", () => {
  assert.equal(
    tierFromUserDoc({subscription: {tier: "pro", status: "canceled"}}),
    "pro"
  );
  assert.equal(
    tierFromUserDoc({subscription: {tier: "light", status: "grace"}}),
    "light"
  );
});

test("끝났거나 적힌 것이 없으면 무료", () => {
  assert.equal(
    tierFromUserDoc({subscription: {tier: "pro", status: "expired"}}),
    "free"
  );
  assert.equal(tierFromUserDoc({nickname: "춘배"}), "free");
  assert.equal(tierFromUserDoc(null), "free");
  assert.equal(tierFromUserDoc({subscription: "pro"}), "free");
});

test("모르는 단계 이름은 무료로 본다", () => {
  assert.equal(
    tierFromUserDoc({subscription: {tier: "platinum", status: "active"}}),
    "free"
  );
});

test("단계별 기본 한도는 무료 3, 라이트 15, 프로 60", () => {
  assert.deepEqual(DEFAULT_ASSIST_LIMITS, {
    free: 3,
    light: 15,
    plus: 30,
    pro: 60,
    max: 120,
  });
  assert.equal(limitForTier("plus"), 30);
  assert.equal(limitForTier("max"), 120);
  assert.equal(
    tierFromUserDoc({subscription: {tier: "max", status: "active"}}),
    "max"
  );
  assert.equal(
    tierFromUserDoc({subscription: {tier: "plus", status: "grace"}}),
    "plus"
  );
  assert.equal(limitForTier("free"), 3);
  assert.equal(limitForTier("light"), 15);
  assert.equal(limitForTier("pro"), 60);
});

test("설정에 적힌 한도가 기본값을 이긴다", () => {
  assert.equal(limitForTier("light", {light: 20}), 20);
  assert.equal(limitForTier("pro", {light: 20}), 60, "안 적은 단계는 기본값");
});

test("이상한 한도 값은 버린다", () => {
  assert.deepEqual(sanitizeLimits({light: -1, pro: 1.5, free: 99999}), {});
  assert.deepEqual(sanitizeLimits({light: 0, pro: 10000}), {
    light: 0,
    pro: 10000,
  });
  assert.deepEqual(sanitizeLimits("15"), {});
  assert.equal(limitForTier("pro", {pro: "many"}), 60);
});
