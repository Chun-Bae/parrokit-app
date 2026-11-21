// 구독으로 매달 주는 패롯.
//
// 라이트 100, 프로 400을 기간마다 한 번 준다. 받은 것은 보통 패롯과 따로
// 세고(subParrots), 쓸 때 먼저 깎인다. 같은 기간에 이벤트가 여러 번 와도
// 장부 키가 같아서 한 번만 들어간다.
//
// 안 쓰고 남은 것은 다음 기간으로 넘어간다. 지우는 것은 구독이 끝났을
// 때(status 'expired')뿐이다. 화면의 subscriptionParrotNotice가 이 규칙을
// 그대로 적는다(5차 529). '기간이 끝나면 사라진다'로 읽히게 적어 두었던
// 것을 고쳤다 - 갱신에서는 지우지 않는다.

import * as admin from "firebase-admin";
import {applyLedger} from "./wallet";
import {SubscriptionState, SubscriptionTier} from "./subscriptionEvent";
import {sanitizeLimits, TierLimits} from "./subscriptionTier";

/** 단계별로 매달 주는 패롯. config/subscription.grants로 바꿀 수 있다. */
export const DEFAULT_GRANTS: TierLimits = {
  free: 0,
  light: 100,
  plus: 250,
  pro: 400,
  max: 700,
};

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
 * 기간이 아직 남았는데 갈아탄 것으로 볼 최소 간격(ms).
 *
 * 갱신은 이전 기간이 끝나는 그 시각에 온다(차이 ~0). 업그레이드는 기간
 * 한가운데서 오므로 며칠이 남아 있다. 시계 오차로 갱신을 업그레이드로
 * 잘못 보면 지급이 깎이므로 넉넉히 1분을 둔다.
 */
const MID_PERIOD_MARGIN_MS = 60_000;

/** 지난번에 이 사람에게 준 구독 패롯. users/{uid}.subscription에 적어 둔다. */
export interface GrantedRecord {
  /** 그 기간에 준 누계. 단계를 올렸으면 올린 단계의 전액이다. */
  amount: number;
  /** 그 지급이 속한 기간의 끝(ms). */
  periodEnd: number | null;
}

/**
 * 이번에 실제로 줄 패롯 수. 기간 중에 단계를 올렸으면 차액만 준다(5차 530).
 *
 * 업그레이드하면 스토어가 남은 기간을 비례 환불하고 새 기간을 시작한다.
 * 그래서 장부 키(tier+periodEnd)가 달라져 전액이 한 번 더 들어갔다.
 * 라이트(100) 뒤 프로로 올리면 500개가 됐다 - 프로를 바로 샀으면 400인데.
 * 한 단계씩 밟으면 1,450개까지 갔다.
 *
 * @param {number} full 새 단계가 한 기간에 받는 전액
 * @param {GrantedRecord | null} granted 지난번 지급 기록
 * @param {number} eventAtMs 이번 이벤트 시각
 * @return {number} 이번에 줄 수(0이면 주지 않는다)
 */
export function grantAmountFor(
  full: number,
  granted: GrantedRecord | null,
  eventAtMs: number
): number {
  if (!granted || granted.periodEnd == null) return full;
  const left = granted.periodEnd - eventAtMs;
  // 이전 기간이 이미 끝났으면 정상 갱신이다. 전액을 준다.
  if (left <= MID_PERIOD_MARGIN_MS) return full;
  const already = granted.amount > 0 ? granted.amount : 0;
  return Math.max(full - already, 0);
}

/**
 * 저장된 subscription 맵에서 지난 지급 기록을 읽는다.
 *
 * @param {unknown} saved users/{uid}.subscription
 * @return {GrantedRecord | null} 읽은 기록. 없으면 null.
 */
export function grantedFrom(saved: unknown): GrantedRecord | null {
  if (typeof saved !== "object" || saved === null) return null;
  const map = saved as Record<string, unknown>;
  const amount = map.grantedAmount;
  const periodEnd = map.grantedPeriodEnd;
  if (typeof amount !== "number") return null;
  return {
    amount: Math.trunc(amount),
    periodEnd: typeof periodEnd === "number" ? Math.trunc(periodEnd) : null,
  };
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
 * @param {GrantedRecord | null} granted 저장하기 전의 지급 기록
 * @return {Promise<number>} 이번에 넣은 패롯 수(이미 넣었으면 0)
 */
export async function grantSubscriptionParrots(
  state: SubscriptionState,
  granted: GrantedRecord | null = null
): Promise<number> {
  if (!shouldGrant(state)) return 0;
  const full = grantForTier(state.tier, await loadGrants());
  if (full <= 0) return 0;
  const amount = grantAmountFor(full, granted, state.eventAtMs);
  if (amount <= 0) return 0;
  const result = await applyLedger(
    state.uid,
    {subParrots: amount},
    {
      key: grantKey(state.tier, state.periodEnd),
      reason: "sub_grant",
      meta: {tier: state.tier, periodEnd: state.periodEnd, full},
    }
  );
  if (!result.applied) return 0;
  // 이번 기간에 이 사람이 받은 누계를 적어 둔다. 또 올리면 여기서 뺀다.
  try {
    await admin
      .firestore()
      .collection("users")
      .doc(state.uid)
      .set(
        {
          subscription: {
            grantedAmount: full,
            grantedPeriodEnd: state.periodEnd,
          },
        },
        {merge: true}
      );
  } catch (error) {
    // 적지 못해도 패롯은 들어갔다. 다음 업그레이드에서 전액이 또 들어갈 뿐.
    console.error("[Subscription] granted record write failed", error);
  }
  return amount;
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
