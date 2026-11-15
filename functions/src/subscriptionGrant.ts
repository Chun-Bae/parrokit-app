// 구독으로 매달 주는 패롯.
//
// 라이트 100, 프로 400을 기간마다 한 번 준다. 받은 것은 보통 패롯과 따로
// 세고(subParrots), 쓸 때 먼저 깎이고, 기간이 끝나면 남은 것은 사라진다.
// 같은 기간에 이벤트가 여러 번 와도 장부 키가 같아서 한 번만 들어간다.

import * as admin from "firebase-admin";
import {applyLedger} from "./wallet";
import {SubscriptionState, SubscriptionTier} from "./subscriptionEvent";
import {sanitizeLimits, TierLimits} from "./subscriptionTier";

/** 단계별로 매달 주는 패롯. config/subscription.grants로 바꿀 수 있다. */
export const DEFAULT_GRANTS: TierLimits = {free: 0, light: 100, pro: 400};

const CONFIG_DOC = "config/subscription";

/**
 * 이 단계가 이번 기간에 받을 패롯 수.
 *
 * @param {SubscriptionTier} tier 단계
 * @param {Partial<TierLimits>} overrides 설정에서 읽은 값
 * @return {number} 줄 패롯 수
 */
export function grantForTier(
  tier: SubscriptionTier,
  overrides: Partial<TierLimits> = {}
): number {
  return {...DEFAULT_GRANTS, ...sanitizeLimits(overrides)}[tier];
}

/**
 * 이번 기간의 장부 키. 같은 기간에는 한 번만 들어간다.
 *
 * 기간 끝(periodEnd)이 기간을 구분하는 값이다. 갱신될 때마다 뒤로 밀린다.
 *
 * @param {SubscriptionTier} tier 단계
 * @param {number | null} periodEnd 기간이 끝나는 시각(ms)
 * @return {string} 장부 문서 id
 */
export function grantKey(
  tier: SubscriptionTier,
  periodEnd: number | null
): string {
  return `sub_grant_${tier}_${periodEnd ?? "unknown"}`;
}

/**
 * 기간이 끝나 남은 구독 패롯을 지울 때 쓰는 장부 키.
 *
 * @param {number | null} periodEnd 기간이 끝난 시각(ms)
 * @return {string} 장부 문서 id
 */
export function expireKey(periodEnd: number | null): string {
  return `sub_expire_${periodEnd ?? "unknown"}`;
}

/**
 * 이 상태에서 패롯을 줘야 하는지.
 *
 * 끝난 구독(expired)과 무료는 주지 않는다. 해지를 예약했어도(canceled)
 * 기간이 남아 있으면 그 기간 몫은 준다.
 *
 * @param {SubscriptionState} state 저장한 상태
 * @return {boolean} 줄지
 */
export function shouldGrant(state: SubscriptionState): boolean {
  return state.tier !== "free" && state.status !== "expired";
}

/**
 * 설정에서 단계별 지급량을 읽는다. 없으면 기본값.
 *
 * @return {Promise<Partial<TierLimits>>} 설정값
 */
export async function loadGrants(): Promise<Partial<TierLimits>> {
  try {
    const snapshot = await admin.firestore().doc(CONFIG_DOC).get();
    return sanitizeLimits(snapshot.data()?.grants);
  } catch (error) {
    console.error("[Subscription] grants read failed", error);
    return {};
  }
}

/**
 * 이번 기간 몫을 지갑에 넣는다. 이미 넣었으면 아무 일도 하지 않는다.
 *
 * @param {SubscriptionState} state 저장한 상태
 * @return {Promise<number>} 이번에 넣은 패롯 수(이미 넣었으면 0)
 */
export async function grantSubscriptionParrots(
  state: SubscriptionState
): Promise<number> {
  if (!shouldGrant(state)) return 0;
  const amount = grantForTier(state.tier, await loadGrants());
  if (amount <= 0) return 0;
  const result = await applyLedger(
    state.uid,
    {subParrots: amount},
    {
      key: grantKey(state.tier, state.periodEnd),
      reason: "sub_grant",
      meta: {tier: state.tier, periodEnd: state.periodEnd},
    }
  );
  return result.applied ? amount : 0;
}

/**
 * 기간이 끝났으면 남은 구독 패롯을 지운다. 보통 패롯은 건드리지 않는다.
 *
 * @param {SubscriptionState} state 저장한 상태
 * @return {Promise<number>} 지운 패롯 수
 */
export async function expireSubscriptionParrots(
  state: SubscriptionState
): Promise<number> {
  if (state.status !== "expired") return 0;
  const ref = admin.firestore().collection("users").doc(state.uid);
  const left = (await ref.get()).data()?.subParrots;
  const amount = typeof left === "number" ? Math.trunc(left) : 0;
  if (amount <= 0) return 0;
  const result = await applyLedger(
    state.uid,
    {subParrots: -amount},
    {
      key: expireKey(state.periodEnd),
      reason: "sub_expire",
      meta: {tier: state.tier, periodEnd: state.periodEnd},
    }
  );
  return result.applied ? amount : 0;
}
