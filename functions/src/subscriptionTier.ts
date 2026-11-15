// 서버가 "이 사람이 지금 어느 단계인가"를 한 곳에서 판단한다.
//
// 단계는 onSubscriptionEvent가 users/{uid}.subscription에 적어 둔다. 혜택을
// 주는 쪽(문장 도우미 한도 등)은 그 문서를 읽기만 한다. 앱이 보낸 값은 믿지 않는다.

import * as admin from "firebase-admin";
import {SubscriptionTier} from "./subscriptionEvent";

/** 단계별 하루 한도(문장 도우미). config 문서로 덮어쓸 수 있다. */
export interface TierLimits {
  free: number;
  light: number;
  pro: number;
}

export const DEFAULT_ASSIST_LIMITS: TierLimits = {free: 3, light: 15, pro: 60};

/**
 * users/{uid}.subscription 맵에서 지금 쓸 수 있는 단계를 읽는다.
 *
 * 해지를 예약했거나(canceled) 결제가 밀려도(grace) 기간이 끝나기 전까지는
 * 혜택을 그대로 준다. 끝났으면(expired) 무료다.
 *
 * @param {unknown} data users/{uid} 문서 내용
 * @return {SubscriptionTier} 지금 단계
 */
export function tierFromUserDoc(data: unknown): SubscriptionTier {
  if (!data || typeof data !== "object") return "free";
  const sub = (data as Record<string, unknown>).subscription;
  if (!sub || typeof sub !== "object") return "free";
  const map = sub as Record<string, unknown>;
  if (map.status === "expired") return "free";
  if (map.tier === "pro") return "pro";
  if (map.tier === "light") return "light";
  return "free";
}

/**
 * 단계에 맞는 하루 한도를 고른다. 설정에 적힌 값이 있으면 그것을 쓴다.
 *
 * @param {SubscriptionTier} tier 단계
 * @param {Partial<TierLimits>} limits 설정에서 읽은 값
 * @return {number} 하루 한도
 */
export function limitForTier(
  tier: SubscriptionTier,
  limits: Partial<TierLimits> = {}
): number {
  const merged = {...DEFAULT_ASSIST_LIMITS, ...sanitizeLimits(limits)};
  return merged[tier];
}

/**
 * 설정 문서에서 읽은 한도 값 중 쓸 수 있는 것만 남긴다.
 *
 * @param {unknown} value 설정 문서의 tierLimits 값
 * @return {Partial<TierLimits>} 쓸 수 있는 값만
 */
export function sanitizeLimits(value: unknown): Partial<TierLimits> {
  if (!value || typeof value !== "object") return {};
  const map = value as Record<string, unknown>;
  const out: Partial<TierLimits> = {};
  for (const key of ["free", "light", "pro"] as const) {
    const limit = map[key];
    if (Number.isInteger(limit) && (limit as number) >= 0 &&
      (limit as number) <= 10000) {
      out[key] = limit as number;
    }
  }
  return out;
}

/**
 * 서버에 적힌 이 사람의 단계를 읽는다. 읽지 못하면 무료로 본다.
 *
 * @param {string} uid 사용자 ID
 * @return {Promise<SubscriptionTier>} 지금 단계
 */
export async function loadTier(uid: string): Promise<SubscriptionTier> {
  try {
    const snapshot = await admin.firestore().doc(`users/${uid}`).get();
    return tierFromUserDoc(snapshot.data());
  } catch (error) {
    console.error("[Subscription] tier read failed", error);
    return "free";
  }
}
