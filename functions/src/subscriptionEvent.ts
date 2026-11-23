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
import {timingSafeEqual} from "crypto";
import {
  expireSubscriptionParrots,
  GrantedRecord,
  grantedFrom,
  grantSubscriptionParrots,
} from "./subscriptionGrant";
import {
  coinPurchaseFromEvent,
  coinRefundFromEvent,
  grantPurchasedParrots,
  revokeRefundedParrots,
} from "./coinGrant";
import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";

/**
 * RevenueCat 대시보드 Webhook의 Authorization 헤더에 적은 값.
 *
 * Secret Manager에 둔다(R2 키와 같은 방식). .env에 적으면 그 파일이
 * .gitignore에 걸려 있지 않아 실수로 커밋될 수 있다.
 */
const webhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

/**
 * 헤더가 맞는지. 시간차로 값을 알아내지 못하게 상수 시간으로 비교한다.
 *
 * @param {string | undefined} header 요청의 Authorization 헤더.
 * @param {string} expected 대시보드에 적어 둔 값.
 * @return {boolean} 같으면 true.
 */
export function authorized(
  header: string | undefined,
  expected: string
): boolean {
  if (typeof header !== "string") return false;
  const a = Buffer.from(header);
  const b = Buffer.from(expected);
  // timingSafeEqual은 길이가 다르면 던진다. 길이도 비교 대상이므로
  // 먼저 거르되, 그 뒤 비교는 상수 시간으로 한다.
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

/** 구독 단계. 앱의 SubscriptionTier와 같은 말이다. */
export type SubscriptionTier = "free" | "light" | "plus" | "pro" | "max";

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
export const PLUS_ENTITLEMENT = "parrokit_sub_plus";
export const PRO_ENTITLEMENT = "parrokit_sub_pro";
export const MAX_ENTITLEMENT = "parrokit_sub_max";

/** 혜택이 끝났다고 보는 이벤트. */
const ENDED_TYPES = new Set(["EXPIRATION", "REFUND", "SUBSCRIPTION_PAUSED"]);

/**
 * 구독 상태를 바꿔도 되는 이벤트. 여기 없는 것은 건드리지 않는다.
 *
 * 전에는 타입을 가리지 않고 모두 구독 상태로 썼다. 그래서 구독자가
 * 패롯을 충전하면(NON_RENEWING_PURCHASE) entitlement_ids에 구독
 * entitlement가 없어 tierOf가 "free"를 주고, statusOf가 "expired"가 되어
 * **돈 내고 산 구독이 만료로 저장되고 남은 subParrots까지 지워졌다.**
 * 아직 실제 웹훅 호출 기록이 없어 겪은 사람은 없다(5차 568).
 *
 * 모르는 타입은 무시한다. RevenueCat이 나중에 새 1회성 이벤트를 더해도
 * 구독이 날아가지 않게, 막는 쪽이 아니라 **허용하는 쪽**을 적는다.
 */
export const SUBSCRIPTION_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "CANCELLATION",
  "UNCANCELLATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
  "SUBSCRIPTION_EXTENDED",
  "EXPIRATION",
  "REFUND",
  "REFUND_REVERSED",
  "TRANSFER",
]);

function toInt(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ?
    Math.trunc(value) :
    null;
}

function tierOf(entitlements: unknown): SubscriptionTier {
  if (!Array.isArray(entitlements)) return "free";
  // 높은 단계부터 본다. 둘 이상 들고 있으면(갈아타는 중) 높은 쪽.
  if (entitlements.includes(MAX_ENTITLEMENT)) return "max";
  if (entitlements.includes(PRO_ENTITLEMENT)) return "pro";
  if (entitlements.includes(PLUS_ENTITLEMENT)) return "plus";
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
  // 대시보드의 'Send test event'. 실제 구독이 아니다(5차 528).
  //
  // 본문의 app_user_id는 임시 id 접두사가 없는 그냥 UUID라 위 걸름을
  // 지나간다. 그대로 두면 테스트를 누를 때마다 users/<그 UUID>에
  // subscription이 적혀 가짜 문서가 쌓인다.
  if (type === "TEST") return null;
  // 구독과 상관없는 이벤트(패롯 충전 같은 1회성 구매)는 상태를 건드리지
  // 않는다. 위 SUBSCRIPTION_TYPES의 설명을 본다.
  if (!SUBSCRIPTION_TYPES.has(type)) return null;

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

// index.ts가 코드 전체(genkit, TTS 등)를 함께 불러와서 기본 256MiB로는 모자란다.
export const onSubscriptionEvent = onRequest(
  {memory: "512MiB", secrets: [webhookSecret]},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("method not allowed");
      return;
    }
    // RevenueCat 대시보드에 적은 값과 같아야 받는다.
    //
    // 비밀값이 없으면 **거절한다**. 전에는 `if (expected && ...)`라 값이
    // 없으면 검사를 통째로 건너뛰었고, 실제로 설정돼 있지 않아서 주소만
    // 알면 누구나 가짜 결제 이벤트를 넣어 맥스 단계와 패롯을 받을 수
    // 있었다. 설정을 빠뜨린 쪽이 뚫린 쪽보다 낫다.
    const expected = webhookSecret.value();
    if (!expected) {
      // 로그는 영어로 둔다. 서버의 한글 글은 사용자에게 그대로 보일 수
      // 있어 앱 말투 규칙을 받는다(5차 438).
      console.error(
        "[Subscription] REVENUECAT_WEBHOOK_SECRET missing - event rejected. " +
          "Set it with functions:secrets:set and redeploy."
      );
      res.status(503).send("webhook secret not configured");
      return;
    }
    if (!authorized(req.get("authorization"), expected)) {
      res.status(401).send("unauthorized");
      return;
    }

    // 패롯 충전(1회성 구매)은 구독 상태를 건드리지 않고 지급만 한다
    // (5차 568). 영수증 확인은 RevenueCat이 했고, 우리는 이벤트 id로
    // 한 번만 넣는다.
    // 충전 환불이 먼저다. REFUND는 구독 쪽 allowlist에도 있어서, 가리지
    // 않으면 충전을 무른 것이 구독 만료로 흘러간다(5차 568).
    const refund = coinRefundFromEvent(req.body);
    if (refund) {
      try {
        const taken = await revokeRefundedParrots(refund);
        res.status(200).send(taken > 0 ? "revoked" : "nothing to revoke");
      } catch (error) {
        console.error("[Subscription] coin refund failed", error);
        res.status(500).send("coin refund failed");
      }
      return;
    }

    const purchase = coinPurchaseFromEvent(req.body);
    if (purchase) {
      try {
        const applied = await grantPurchasedParrots(purchase);
        res.status(200).send(applied ? "granted" : "duplicate");
      } catch (error) {
        console.error("[Subscription] coin grant failed", error);
        // 다시 보내 달라고 한다. 같은 이벤트 id라 두 번 들어오지 않는다.
        res.status(500).send("coin grant failed");
      }
      return;
    }

    const next = subscriptionFromEvent(req.body);
    if (!next) {
      // 우리 계정 이벤트가 아니면 조용히 받아들인다. 다시 보내지 않게 200.
      res.status(200).send("ignored");
      return;
    }

    const ref = admin.firestore().collection("users").doc(next.uid);
    let saveApplied = true;
    // 기간 중에 단계를 올렸는지 보려면 저장하기 전의 지급 기록이 필요하다
    // (5차 530). 트랜잭션이 덮어쓰기 전에 꺼내 둔다.
    let granted: GrantedRecord | null = null;
    await admin.firestore().runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const saved = snapshot.data()?.subscription as
        | FirebaseFirestore.DocumentData
        | undefined;
      granted = grantedFrom(saved);
      if (shouldSkipEvent(saved, next)) {
        saveApplied = false;
        return;
      }
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

    if (saveApplied) {
      // 이번 기간 몫을 넣고(같은 기간이면 한 번만), 끝났으면 남은 것을 지운다.
      try {
        await grantSubscriptionParrots(next, granted);
        await expireSubscriptionParrots(next);
      } catch (error) {
        // 지급이 실패해도 상태는 저장됐다. 다음 이벤트에서 같은 키로 다시 시도된다.
        console.error("[Subscription] grant failed", error);
      }
    }

    res.status(200).send("ok");
  }
);
