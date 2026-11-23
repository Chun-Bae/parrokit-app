/**
 * 연습 보상 크래커를 서버가 뽑고 지급한다(5차 568).
 *
 * 전에는 앱이 뽑고 앱이 Firestore에 더했다. 뽑기 표도 상한 장부도 기기
 * 안(SharedPreferences)에 있어서, 마음먹으면 얼마든지 올릴 수 있었다.
 * 크래커는 환전으로 패롯이 되고, 패롯은 Whisper·Gemini·R2를 쓰는 값이라
 * 그만큼 서버 비용이 나간다.
 *
 * 이제 뽑기와 상한을 서버가 쥔다. 앱은 '한 번 연습했다'고만 말한다.
 *
 * 레벨은 앱이 보낸다. 로컬 XP라 믿을 수 없지만, 레벨이 늘리는 것은
 * **하루** 상한뿐이고 300~600으로 끊는다. 주(1,500)·달(5,000) 상한은
 * 서버가 쥐고 있어 총량은 움직이지 않는다.
 */

import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {ENFORCE_APP_CHECK} from "./appCheck";
import {applyLedger, requestIdOf} from "./wallet";

/** 한 번 뽑을 때 나올 액수와 무게. 앱의 rewardTiers와 같은 값이다. */
export const REWARD_TIERS: ReadonlyArray<{crackers: number; weight: number}> = [
  {crackers: 10, weight: 600},
  {crackers: 30, weight: 280},
  {crackers: 100, weight: 100},
  {crackers: 300, weight: 18},
  {crackers: 1000, weight: 2},
];

/** 무게의 합. 1,000이라 무게를 '1,000번에 몇 번'으로 읽으면 된다. */
export const REWARD_TOTAL_WEIGHT = REWARD_TIERS.reduce(
  (sum, tier) => sum + tier.weight,
  0
);

/** 하루 기본 상한. 레벨이 올라도 600을 넘지 않는다. */
export const REWARD_DAILY_CAP = 300;
/** 레벨로 늘릴 수 있는 하루 상한의 끝. */
export const REWARD_DAILY_CAP_MAX = 600;
/** 한 주(7일) 상한. */
export const REWARD_WEEKLY_CAP = 1500;
/** 한 달(28일) 상한. */
export const REWARD_MONTHLY_CAP = 5000;

/**
 * 레벨로 늘어난 하루 상한. 앱의 rewardDailyCapFor와 같은 식이다.
 * @param {number} level 캐릭터 레벨
 * @return {number} 하루 상한
 */
export function dailyCapFor(level: number): number {
  const safe = Number.isFinite(level) ? Math.trunc(level) : 1;
  const raw = REWARD_DAILY_CAP + 20 * (Math.max(1, safe) - 1);
  return Math.min(Math.max(raw, REWARD_DAILY_CAP), REWARD_DAILY_CAP_MAX);
}

/**
 * 한 번 뽑는다. 상한은 보지 않는다.
 * @param {number} roll 0 이상 REWARD_TOTAL_WEIGHT 미만의 수
 * @return {number} 뽑힌 크래커
 */
export function rollCrackers(roll: number): number {
  let passed = 0;
  for (const tier of REWARD_TIERS) {
    passed += tier.weight;
    if (roll < passed) return tier.crackers;
  }
  return REWARD_TIERS[REWARD_TIERS.length - 1].crackers;
}

/**
 * 하루·주·달을 가르는 열쇠. 한국 자정 기준으로 앱과 같다.
 * @param {Date} now 지금
 * @return {{day: string, week: string, month: string}} 날짜 열쇠
 */
export function rewardKeys(now: Date): {
  day: string;
  week: string;
  month: string;
} {
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = kst.getUTCMonth() + 1;
  const d = kst.getUTCDate();
  // 주는 그 주의 월요일로 센다.
  const weekday = (kst.getUTCDay() + 6) % 7;
  const monday = new Date(kst.getTime() - weekday * 24 * 60 * 60 * 1000);
  return {
    day: `${y}-${m}-${d}`,
    week: `${monday.getUTCFullYear()}-${monday.getUTCMonth() + 1}-${
      monday.getUTCDate()
    }`,
    month: `${y}-${m}`,
  };
}

/** 서버가 들고 있는 상한 장부. */
export interface RewardLedger {
  dayKey: string;
  day: number;
  weekKey: string;
  week: number;
  monthKey: string;
  month: number;
}

/**
 * 저장된 장부를 지금 날짜에 맞춰 읽는다. 날이 바뀐 칸은 0으로 본다.
 * @param {unknown} saved 저장된 값
 * @param {Date} now 지금
 * @return {RewardLedger} 읽은 장부
 */
export function readLedger(saved: unknown, now: Date): RewardLedger {
  const keys = rewardKeys(now);
  const raw = (saved ?? {}) as Record<string, unknown>;
  const num = (value: unknown): number =>
    typeof value === "number" && Number.isFinite(value) ?
      Math.max(0, Math.trunc(value)) :
      0;
  return {
    dayKey: keys.day,
    day: raw.dayKey === keys.day ? num(raw.day) : 0,
    weekKey: keys.week,
    week: raw.weekKey === keys.week ? num(raw.week) : 0,
    monthKey: keys.month,
    month: raw.monthKey === keys.month ? num(raw.month) : 0,
  };
}

/** 어느 상한에 걸렸는지. 안 걸렸으면 null. */
export type RewardCap = "day" | "week" | "month" | null;

/**
 * 상한을 보고 실제로 줄 액수를 정한다.
 * @param {RewardLedger} ledger 지금 장부
 * @param {number} rolled 뽑은 액수
 * @param {number} dailyCap 이 사람의 하루 상한
 * @return {{crackers: number, cap: RewardCap}} 줄 액수와 걸린 상한
 */
export function applyCaps(
  ledger: RewardLedger,
  rolled: number,
  dailyCap: number
): {crackers: number; cap: RewardCap} {
  const room = [
    {cap: "day" as const, left: dailyCap - ledger.day},
    {cap: "week" as const, left: REWARD_WEEKLY_CAP - ledger.week},
    {cap: "month" as const, left: REWARD_MONTHLY_CAP - ledger.month},
  ];
  // 가장 빡빡한 것이 정한다.
  let tightest = room[0];
  for (const one of room) {
    if (one.left < tightest.left) tightest = one;
  }
  const left = Math.max(0, tightest.left);
  if (left >= rolled) return {crackers: rolled, cap: null};
  return {crackers: left, cap: tightest.cap};
}

/**
 * 연습 한 번의 보상을 뽑아 지급한다.
 *
 * 앱은 뽑은 액수를 보내지 않는다. 보내 봐야 믿을 수 없다.
 */
export const grantPracticeReward = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인하면 쓸 수 있어요.");
    }

    const dailyCap = dailyCapFor(Number(request.data?.level ?? 1));
    const key = `practice_reward_${requestIdOf(request.data?.requestId)}`;
    const now = new Date();
    const rolled = rollCrackers(
      Math.floor(Math.random() * REWARD_TOTAL_WEIGHT)
    );

    const ref = admin.firestore().collection("users").doc(uid);
    // 장부와 지급이 따로 돌면, 지급만 되고 장부가 안 늘어 상한이 새 버린다.
    // 한 트랜잭션에서 읽고 쓰기 위해 장부는 사용자 문서에 둔다.
    const decided = await admin.firestore().runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const ledger = readLedger(snapshot.data()?.practiceReward, now);
      const {crackers, cap} = applyCaps(ledger, rolled, dailyCap);
      if (crackers <= 0) return {crackers: 0, cap};
      tx.set(
        ref,
        {
          practiceReward: {
            dayKey: ledger.dayKey,
            day: ledger.day + crackers,
            weekKey: ledger.weekKey,
            week: ledger.week + crackers,
            monthKey: ledger.monthKey,
            month: ledger.month + crackers,
          },
        },
        {merge: true}
      );
      return {crackers, cap};
    });

    if (decided.crackers <= 0) {
      return {crackers: 0, rolled, cap: decided.cap, applied: false};
    }

    const result = await applyLedger(
      uid,
      {crackers: decided.crackers},
      {key, reason: "practice_reward", meta: {rolled, dailyCap}}
    );

    return {
      crackers: result.applied ? decided.crackers : 0,
      rolled,
      cap: decided.cap,
      applied: result.applied,
      balance: result.crackers,
    };
  }
);
