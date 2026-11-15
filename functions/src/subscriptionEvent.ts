/* eslint-disable require-jsdoc */
// RevenueCat Webhook을 받아 users/{uid}.subscription을 서버가 정한다.
//
// 앱은 이 값을 읽기만 한다. 앱이 스스로 '나는 프로'라고 쓰지 못하게 규칙으로
// 막는다(배포 필요). 스토어 상품과 entitlement가 아직 없어도 이 함수는
// 그대로 돌아가고, 아무 일도 하지 않을 뿐이다.
//
// 멱등: 같은 이벤트가 다시 와도 한 번만 반영한다. 늦게 도착한 옛 이벤트가
// 새 상태를 덮지 않게 이벤트 시각을 함께 본다.

import * as admin from "firebase-admin";
import {onRequest} from "firebase-functions/v2/https";

/** 구독 단계. 앱의 SubscriptionTier와 같은 말이다. */
export type SubscriptionTier = "free" | "light" | "pro";

/**
 * 구독 상태.
 * - active: 쓸 수 있다
 * - grace: 결제가 밀렸지만 아직 쓸 수 있다
 * - canceled: 해지를 예약했고 기간이 끝날 때까지 쓸 수 있다
 * - expired: 끝났다(환불 포함)
 */
export type SubscriptionStatus = "active" | "grace" | "canceled" | "expired";

export interface SubscriptionState {
  uid: string;
  tier: SubscriptionTier;
  status: SubscriptionStatus;
  /** 이 기간이 끝나는 시각(ms). 모르면 null. */
  periodEnd: number | null;
  store: string;
  eventId: string;
  eventAtMs: number;
}

/** entitlement 이름. RevenueCat 대시보드에 같은 이름으로 만든다. */
export const LIGHT_ENTITLEMENT = "parrokit_sub_light";
export const PRO_ENTITLEMENT = "parrokit_sub_pro";

/** 혜택이 끝났다고 보는 이벤트. */
const ENDED_TYPES = new Set(["EXPIRATION", "REFUND", "SUBSCRIPTION_PAUSED"]);

function toInt(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ?
    Math.trunc(value) :
    null;
}

function tierOf(entitlements: unknown): SubscriptionTier {
  if (!Array.isArray(entitlements)) return "free";
  if (entitlements.includes(PRO_ENTITLEMENT)) return "pro";
  if (entitlements.includes(LIGHT_ENTITLEMENT)) return "light";
  return "free";
}

function statusOf(type: string, tier: SubscriptionTier): SubscriptionStatus {
  if (tier === "free" || ENDED_TYPES.has(type)) return "expired";
  if (type === "BILLING_ISSUE") return "grace";
  if (type === "CANCELLATION") return "canceled";
  return "active";
}

/**
 * Webhook 본문에서 저장할 상태를 뽑는다. 읽을 수 없으면 null.
 * @param {unknown} body 요청 본문
 * @return {SubscriptionState | null} 저장할 상태
 */
export function subscriptionFromEvent(body: unknown): SubscriptionState | null {
  if (typeof body !== "object" || body === null) return null;
  const event = (body as {event?: unknown}).event;
  if (typeof event !== "object" || event === null) return null;
  const data = event as Record<string, unknown>;

  const uid = typeof data.app_user_id === "string" ? data.app_user_id : "";
  const type = typeof data.type === "string" ? data.type : "";
  if (!uid || !type) return null;
  // RevenueCat이 아직 로그인 전 임시 id를 보내면 우리 계정이 아니다.
  if (uid.startsWith("$RCAnonymousID:")) return null;

  const tier = tierOf(data.entitlement_ids);
  const eventId = typeof data.id === "string" && data.id.length > 0 ?
    data.id :
    `${uid}_${type}_${toInt(data.event_timestamp_ms) ?? 0}`;

  return {
    uid,
    tier: statusOf(type, tier) === "expired" ? "free" : tier,
    status: statusOf(type, tier),
    periodEnd: toInt(data.expiration_at_ms),
    store: typeof data.store === "string" ? data.store : "unknown",
    eventId,
    eventAtMs: toInt(data.event_timestamp_ms) ?? Date.now(),
  };
}

/**
 * 늦게 온 옛 이벤트인지. 같은 이벤트가 다시 와도 true.
 * @param {FirebaseFirestore.DocumentData | undefined} saved 저장된 값
 * @param {SubscriptionState} next 새 상태
 * @return {boolean} 건너뛸지
 */
export function shouldSkipEvent(
  saved: FirebaseFirestore.DocumentData | undefined,
  next: SubscriptionState
): boolean {
  if (!saved) return false;
  if (saved.lastEventId === next.eventId) return true;
  const savedAt = toInt(saved.lastEventAtMs);
  return savedAt !== null && savedAt > next.eventAtMs;
}

export const onSubscriptionEvent = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("method not allowed");
    return;
  }
  // RevenueCat 대시보드에 적은 값과 같아야 받는다. 설정 전에는 막지 않는다.
  const expected = process.env.REVENUECAT_WEBHOOK_SECRET;
  if (expected && req.get("authorization") !== expected) {
    res.status(401).send("unauthorized");
    return;
  }

  const next = subscriptionFromEvent(req.body);
  if (!next) {
    // 우리 계정 이벤트가 아니면 조용히 받아들인다. 다시 보내지 않게 200.
    res.status(200).send("ignored");
    return;
  }

  const ref = admin.firestore().collection("users").doc(next.uid);
  await admin.firestore().runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const saved = snapshot.data()?.subscription as
      | FirebaseFirestore.DocumentData
      | undefined;
    if (shouldSkipEvent(saved, next)) return;
    tx.set(
      ref,
      {
        subscription: {
          tier: next.tier,
          status: next.status,
          periodEnd: next.periodEnd,
          store: next.store,
          lastEventId: next.eventId,
          lastEventAtMs: next.eventAtMs,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true}
    );
  });

  res.status(200).send("ok");
});
