/**
 * 레벨 보따리 크래커를 서버가 지급한다(5차 568).
 *
 * 전에는 앱이 로컬 XP로 레벨을 세고 Firestore에 직접 더했다. 규칙이
 * crackers를 막으면 그 길이 끊기므로 서버로 옮긴다.
 *
 * 레벨은 앱이 보낸다. XP가 아직 기기 안에 있어 믿을 수 없지만, 보따리는
 * **표로 고정**돼 있고 받은 데까지를 서버가 적어 둔다. 거짓 레벨을 보내면
 * 한 번에 다 받을 수는 있어도 표 바깥으로는 한 톨도 못 가져간다
 * (Lv.20까지 평생 4,900). XP를 서버로 올리면 그때 레벨도 서버가 센다.
 */

import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {ENFORCE_APP_CHECK} from "./appCheck";
import {applyLedger, requestIdOf} from "./wallet";

/** 레벨별 크래커 보따리. 앱의 levelCrackerRewards와 같은 값이다. */
export const LEVEL_REWARDS: Readonly<Record<number, number>> = {
  5: 300,
  7: 500,
  10: 800,
  13: 800,
  16: 1000,
  20: 1500,
};

/** 표에 적힌 모든 보따리의 합. 평생 받는 총량이다. */
export const LEVEL_REWARD_TOTAL = Object.values(LEVEL_REWARDS).reduce(
  (sum, value) => sum + value,
  0
);

/**
 * [from]보다 크고 [to] 이하인 레벨의 보따리를 모두 더한다.
 * @param {number} from 이미 받은 레벨
 * @param {number} to 지금 레벨
 * @return {number} 줄 크래커
 */
export function rewardBetween(from: number, to: number): number {
  let sum = 0;
  for (const [levelText, crackers] of Object.entries(LEVEL_REWARDS)) {
    const level = Number(levelText);
    if (level > from && level <= to) sum += crackers;
  }
  return sum;
}

/**
 * 앱이 보낸 레벨을 쓸 수 있는 수로 받는다.
 * @param {unknown} value 앱이 보낸 값
 * @return {number} 1 이상 99 이하의 레벨
 */
export function levelOf(value: unknown): number {
  const raw = typeof value === "number" ? Math.trunc(value) : 1;
  if (!Number.isFinite(raw)) return 1;
  return Math.min(Math.max(raw, 1), 99);
}

/**
 * 밀린 레벨 보따리를 지급한다.
 *
 * 처음 부르는 사람은 **지금 레벨까지 이미 받은 것으로 적는다**. 소급해
 * 주면 이미 Lv.20인 사람이 앱을 켜는 순간 표 전체를 한꺼번에 받는다.
 */
export const claimLevelReward = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인하면 쓸 수 있어요.");
    }

    const level = levelOf(request.data?.level);
    const ref = admin.firestore().collection("users").doc(uid);

    // 받은 데까지와 지급을 한 트랜잭션에 둔다. 따로 돌면 지급만 되고
    // 기록이 안 남아 같은 보따리를 또 받는다.
    const decided = await admin.firestore().runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const saved = snapshot.data()?.levelRewardClaimed;
      // 적힌 것이 없으면 지금 레벨까지 받은 것으로 보고 이번엔 주지 않는다.
      if (typeof saved !== "number") {
        tx.set(ref, {levelRewardClaimed: level}, {merge: true});
        return {crackers: 0, claimed: level, first: true};
      }
      const claimed = Math.max(0, Math.trunc(saved));
      if (level <= claimed) return {crackers: 0, claimed, first: false};
      const crackers = rewardBetween(claimed, level);
      tx.set(ref, {levelRewardClaimed: level}, {merge: true});
      return {crackers, claimed: level, first: false};
    });

    if (decided.crackers <= 0) {
      return {
        crackers: 0,
        claimedLevel: decided.claimed,
        first: decided.first,
        applied: false,
      };
    }

    const result = await applyLedger(
      uid,
      {crackers: decided.crackers},
      {
        key: `level_reward_${requestIdOf(request.data?.requestId)}`,
        reason: "level_reward",
        meta: {level, crackers: decided.crackers},
      }
    );

    return {
      crackers: result.applied ? decided.crackers : 0,
      claimedLevel: decided.claimed,
      first: false,
      applied: result.applied,
      balance: result.crackers,
    };
  }
);
