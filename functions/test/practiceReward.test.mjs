// 연습 보상을 서버가 뽑고 상한을 쥔다(5차 568).
//
// 전에는 앱이 뽑고 앱이 Firestore에 더했다. 뽑기 표도 상한 장부도 기기
// 안에 있어서 마음먹으면 올릴 수 있었다.
//
// 실행: functions에서 `npm run test:reward`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {readFileSync} from "node:fs";

const require = createRequire(import.meta.url);
const {
  REWARD_TIERS,
  REWARD_TOTAL_WEIGHT,
  REWARD_DAILY_CAP,
  REWARD_WEEKLY_CAP,
  REWARD_MONTHLY_CAP,
  dailyCapFor,
  rollCrackers,
  rewardKeys,
  readLedger,
  applyCaps,
} = require("../lib/practiceReward.js");

test("무게의 합이 1,000이다", () => {
  assert.equal(REWARD_TOTAL_WEIGHT, 1000);
});

test("뽑기가 표대로 갈린다", () => {
  assert.equal(rollCrackers(0), 10);
  assert.equal(rollCrackers(599), 10);
  assert.equal(rollCrackers(600), 30);
  assert.equal(rollCrackers(879), 30);
  assert.equal(rollCrackers(880), 100);
  assert.equal(rollCrackers(979), 100);
  assert.equal(rollCrackers(980), 300);
  assert.equal(rollCrackers(997), 300);
  assert.equal(rollCrackers(998), 1000);
  assert.equal(rollCrackers(999), 1000);
});

test("무게를 넘겨도 마지막 칸으로 떨어진다", () => {
  assert.equal(rollCrackers(99999), 1000);
});

test("레벨은 하루 상한만 늘리고 600에서 멈춘다", () => {
  assert.equal(dailyCapFor(1), REWARD_DAILY_CAP);
  assert.equal(dailyCapFor(5), 380);
  assert.equal(dailyCapFor(16), 600);
  assert.equal(dailyCapFor(100), 600);
  // 앱이 거짓 레벨을 보내도 여기서 끊긴다.
  assert.equal(dailyCapFor(99999), 600);
  assert.equal(dailyCapFor(0), REWARD_DAILY_CAP);
  assert.equal(dailyCapFor(NaN), REWARD_DAILY_CAP);
});

test("주·달 상한은 레벨과 상관없다", () => {
  assert.equal(REWARD_WEEKLY_CAP, 1500);
  assert.equal(REWARD_MONTHLY_CAP, 5000);
});

test("날이 바뀌면 그 칸만 0으로 본다", () => {
  const now = new Date("2026-11-23T01:00:00Z"); // KST 10:00
  const keys = rewardKeys(now);
  const saved = {
    dayKey: "2026-11-22",
    day: 300,
    weekKey: keys.week,
    week: 900,
    monthKey: keys.month,
    month: 2000,
  };
  const ledger = readLedger(saved, now);
  assert.equal(ledger.day, 0, "날이 바뀌었다");
  assert.equal(ledger.week, 900, "같은 주다");
  assert.equal(ledger.month, 2000, "같은 달이다");
});

test("저장된 것이 없으면 모두 0이다", () => {
  const ledger = readLedger(undefined, new Date());
  assert.equal(ledger.day, 0);
  assert.equal(ledger.week, 0);
  assert.equal(ledger.month, 0);
});

test("이상한 값이 들어 있어도 0으로 본다", () => {
  const now = new Date();
  const keys = rewardKeys(now);
  const ledger = readLedger(
    {dayKey: keys.day, day: "많이", weekKey: keys.week, week: -5},
    now
  );
  assert.equal(ledger.day, 0);
  assert.equal(ledger.week, 0);
});

test("가장 빡빡한 상한이 정한다", () => {
  const base = {dayKey: "", weekKey: "", monthKey: ""};
  // 하루는 널널하고 달이 20만 남았다.
  const tight = {...base, day: 0, week: 0, month: REWARD_MONTHLY_CAP - 20};
  const got = applyCaps(tight, 100, REWARD_DAILY_CAP);
  assert.equal(got.crackers, 20);
  assert.equal(got.cap, "month");
});

test("상한에 안 걸리면 뽑은 대로 준다", () => {
  const ledger = {dayKey: "", day: 0, weekKey: "", week: 0, monthKey: "",
    month: 0};
  const got = applyCaps(ledger, 100, REWARD_DAILY_CAP);
  assert.equal(got.crackers, 100);
  assert.equal(got.cap, null);
});

test("다 썼으면 0을 준다", () => {
  const ledger = {
    dayKey: "", day: REWARD_DAILY_CAP,
    weekKey: "", week: 0, monthKey: "", month: 0,
  };
  const got = applyCaps(ledger, 100, REWARD_DAILY_CAP);
  assert.equal(got.crackers, 0);
  assert.equal(got.cap, "day");
});

// 값이 갈라지면 앱 화면의 안내와 실제로 받는 양이 어긋난다.
test("앱의 뽑기 표·상한과 값이 같다", () => {
  const dart = readFileSync("../lib/core/content/practice_reward.dart", "utf8");
  const tiers = [...dart.matchAll(
    /RewardTier\(crackers:\s*(\d+),\s*weight:\s*(\d+)\)/g
  )].map((m) => ({crackers: Number(m[1]), weight: Number(m[2])}));
  assert.deepEqual(tiers, REWARD_TIERS.map((t) => ({...t})));

  const cap = (name) =>
    Number(dart.match(new RegExp(`const int ${name} = (\\d+);`))[1]);
  assert.equal(cap("rewardDailyCap"), REWARD_DAILY_CAP);
  assert.equal(cap("rewardWeeklyCap"), REWARD_WEEKLY_CAP);
  assert.equal(cap("rewardMonthlyCap"), REWARD_MONTHLY_CAP);
});
