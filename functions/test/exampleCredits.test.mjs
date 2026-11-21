// 패롯으로 산 예문 몫(5차 532).
//
// 하루 한도는 날마다 새로 차고(타이머), 산 몫은 사라지지 않는다. 쓸 때는
// 하루 한도부터 쓴다 - 반대로 하면 산 것이 먼저 닳고 공짜가 남아 손해다.
//
// 실행: functions에서 `npm run test:credits`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {readFileSync} from "node:fs";

const require = createRequire(import.meta.url);
const {
  splitExampleSpend,
  readPackCount,
  EXAMPLE_CREDIT_PACK,
  ASSIST_CREDIT_PACK,
  MAX_CREDIT_PACKS_PER_BUY,
  DEFAULT_EXAMPLE_LIMITS,
} = require("../lib/exampleQuota.js");
const {splitParrotSpend} = require("../lib/wallet.js");

test("무료 하루 예문은 10개다", () => {
  // 5개는 낱말당 3개 상한 때문에 단어 두 개도 못 채웠다.
  assert.equal(DEFAULT_EXAMPLE_LIMITS.free, 10);
  assert.equal(DEFAULT_EXAMPLE_LIMITS.light, 30);
});

test("한 묶음은 3패롯에 10개", () => {
  assert.deepEqual(EXAMPLE_CREDIT_PACK, {parrots: 3, credits: 10});
});

test("뜻·발음은 같은 3패롯에 5번", () => {
  // 한 번에 뜻과 발음을 함께 받아서 구독 환산가가 예문 1개의 두 배다.
  assert.deepEqual(ASSIST_CREDIT_PACK, {parrots: 3, credits: 5});
  assert.equal(ASSIST_CREDIT_PACK.parrots, EXAMPLE_CREDIT_PACK.parrots);
});

test("뜻·발음도 하루분부터 쓴다", () => {
  // 예문과 같은 splitExampleSpend를 쓴다. 한 번에 1씩 깎는다.
  assert.deepEqual(splitExampleSpend(2, 5, 1), {fromDay: 1, fromCredits: 0});
  assert.deepEqual(splitExampleSpend(0, 5, 1), {fromDay: 0, fromCredits: 1});
  assert.deepEqual(splitExampleSpend(0, 0, 1), {fromDay: 0, fromCredits: 0});
});

test("사는 쪽이 둘 다 한 장부에 적는다", () => {
  const source = readFileSync(
    new URL("../src/exampleCredits.ts", import.meta.url),
    "utf8"
  );
  assert.ok(source.includes("{parrots: -parrots, assistCredits: credits}"));
  assert.ok(source.includes("assist_credits_"));
});

test("하루 몫부터 쓰고 모자랄 때만 산 몫을 깎는다", () => {
  // 오늘 7개 남았고 산 몫이 20개. 5개를 쓰면 하루 몫만 준다.
  assert.deepEqual(splitExampleSpend(7, 20, 5), {fromDay: 5, fromCredits: 0});
  // 10개를 쓰면 하루 몫 7 + 산 몫 3.
  assert.deepEqual(splitExampleSpend(7, 20, 10), {fromDay: 7, fromCredits: 3});
});

test("하루 몫을 다 썼으면 산 몫에서만 깎는다", () => {
  assert.deepEqual(splitExampleSpend(0, 20, 4), {fromDay: 0, fromCredits: 4});
});

test("둘 다 모자라면 있는 만큼만 깎는다", () => {
  // 서버가 부른 개수를 이미 잘라 두므로 여기까지 오면 안 되지만,
  // 동시 요청으로 조금 넘칠 수 있다. 음수로 내려가지 않게 한다.
  assert.deepEqual(splitExampleSpend(2, 1, 9), {fromDay: 2, fromCredits: 1});
});

test("쓸 게 없으면 아무것도 깎지 않는다", () => {
  assert.deepEqual(splitExampleSpend(5, 5, 0), {fromDay: 0, fromCredits: 0});
  assert.deepEqual(splitExampleSpend(5, 5, -3), {fromDay: 0, fromCredits: 0});
});

test("남은 수가 음수로 들어와도 버틴다", () => {
  // 한도를 설정으로 낮추면 이미 쓴 수가 한도를 넘을 수 있다.
  assert.deepEqual(splitExampleSpend(-4, 10, 3), {fromDay: 0, fromCredits: 3});
});

test("지갑과 같은 원칙이다 - 먼저 사라질 것부터", () => {
  // 패롯도 소멸하는 구독 몫을 먼저 깎는다. 예문도 날마다 리셋되는 하루 몫이
  // 먼저다. 방향이 같아야 사용자가 한 번만 배운다.
  assert.deepEqual(splitParrotSpend(7, -10), {sub: -7, normal: -3});
  assert.deepEqual(splitExampleSpend(7, 20, 10), {fromDay: 7, fromCredits: 3});
});

test("묶음 수는 1에서 10 사이로 받는다", () => {
  assert.equal(readPackCount(undefined), 1);
  assert.equal(readPackCount("셋"), 1);
  assert.equal(readPackCount(0), 1);
  assert.equal(readPackCount(-5), 1);
  assert.equal(readPackCount(2.9), 2);
  assert.equal(readPackCount(3), 3);
  assert.equal(readPackCount(999), MAX_CREDIT_PACKS_PER_BUY);
  assert.equal(readPackCount(Number.NaN), 1);
});

test("사는 쪽은 패롯과 몫을 한 장부에 적는다", () => {
  // 따로 적으면 중간에 끊겼을 때 패롯만 사라진다.
  const source = readFileSync(
    new URL("../src/exampleCredits.ts", import.meta.url),
    "utf8"
  );
  assert.ok(source.includes("{parrots: -parrots, exampleCredits: credits}"));
  assert.ok(source.includes("example_credits_"));
});
