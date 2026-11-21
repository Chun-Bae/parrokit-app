// 서버에 올린 파일이 얼마나 되는지 서버가 센다.
//
// 전에는 앱이 자기 기기의 클립 목록을 더해서 "서버 사용량"이라고 보여 줬다.
// 기기마다 다르고, 앱이 고치면 그만이라 한도를 정하는 근거로 쓸 수 없다.
// 이제 Storage 트리거가 올라오고 지워지는 것을 보고
// users/{uid}.storage = {usedBytes, objectCount, updatedAt}에 적는다.
//
// 같은 이벤트가 두 번 와도 숫자가 틀어지지 않게, 파일 하나하나의 크기를
// storage_objects/{키}에 적어 두고 그 차이만 더한다.

import {
  onObjectDeleted,
  onObjectFinalized,
} from "firebase-functions/v2/storage";
import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {ENFORCE_APP_CHECK} from "./appCheck";
import {SubscriptionTier} from "./subscriptionEvent";
import {TIER_KEYS, tierFromUserDoc, TierLimits} from "./subscriptionTier";
import {r2Head, r2Secrets} from "./r2Client";
import {createHash} from "crypto";

/** 단계별 서버 저장 한도(바이트). config/subscription.storage로 바꿀 수 있다. */
export const DEFAULT_STORAGE_QUOTAS: TierLimits = {
  free: 0,
  light: 10 * 1024 * 1024 * 1024,
  plus: 20 * 1024 * 1024 * 1024,
  pro: 30 * 1024 * 1024 * 1024,
  max: 80 * 1024 * 1024 * 1024,
};

/**
 * 이 단계가 서버에 담을 수 있는 양.
 *
 * @param {SubscriptionTier} tier 단계
 * @param {Partial<TierLimits>} overrides 설정에서 읽은 값
 * @return {number} 바이트
 */
export function quotaForTier(
  tier: SubscriptionTier,
  overrides: Partial<TierLimits> = {}
): number {
  return {...DEFAULT_STORAGE_QUOTAS, ...sanitizeStorage(overrides)}[tier];
}

/**
 * 설정에서 읽은 한도 중 쓸 수 있는 것만 남긴다.
 * 바이트라서 sanitizeLimits의 상한(10000)으로는 거를 수 없다.
 *
 * @param {unknown} value 설정값
 * @return {Partial<TierLimits>} 쓸 수 있는 값만
 */
export function sanitizeStorage(value: unknown): Partial<TierLimits> {
  if (!value || typeof value !== "object") return {};
  const map = value as Record<string, unknown>;
  const out: Partial<TierLimits> = {};
  const max = 1024 * 1024 * 1024 * 1024; // 1TB
  for (const key of TIER_KEYS) {
    const limit = map[key];
    if (
      typeof limit === "number" &&
      Number.isInteger(limit) &&
      limit >= 0 &&
      limit <= max
    ) {
      out[key] = limit;
    }
  }
  return out;
}

/**
 * 파일 경로에서 주인을 읽는다.
 *
 * 세는 것은 클립뿐이다(users/{uid}/clips/...). 프로필 사진이나 글 사진은
 * 용량 한도와 상관없어야 해서 빼 둔다 — 무료 한도가 0이라, 함께 셌다면
 * 프로필 사진을 바꾼 것만으로 한도를 넘게 된다.
 *
 * @param {string | undefined} name Storage 객체 이름
 * @return {string | null} uid
 */
export function uidFromObjectName(name: string | undefined): string | null {
  if (!name) return null;
  const parts = name.split("/");
  if (parts.length < 4 || parts[0] !== "users" || parts[2] !== "clips") {
    return null;
  }
  return parts[1] || null;
}

/**
 * 객체 이름을 Firestore 문서 id로 쓸 수 있게 바꾼다('/'를 못 쓴다).
 *
 * @param {string} name Storage 객체 이름
 * @return {string} 문서 id
 */
export function objectDocId(name: string): string {
  return createHash("sha256").update(name).digest("base64url");
}

/**
 * 옛 방식으로 만든 문서 id(5차 547).
 *
 * base64url로 바꾼 뒤 400자에서 잘랐다. 400자는 입력 300바이트치인데 키는
 * 512자까지 받으므로, 앞 300바이트가 같은 키들이 한 문서를 썼다. 그러면
 * 한 파일의 크기가 다른 파일 것으로 덮이고 objectCount도 늘지 않아,
 * 사용량이 실제보다 적게 잡히고 한도를 넘겨 올릴 수 있었다.
 *
 * 이미 적어 둔 문서를 버리지 않으려고 읽을 때만 함께 본다.
 *
 * @param {string} name 객체 이름
 * @return {string} 옛 문서 id
 */
export function legacyObjectDocId(name: string): string {
  return Buffer.from(name).toString("base64url").slice(0, 400);
}

/**
 * 한 파일의 크기가 바뀐 만큼만 사용량에 더한다.
 *
 * 같은 이벤트가 다시 와도 적어 둔 크기와 같아서 아무 일도 하지 않는다.
 *
 * @param {string} uid 주인
 * @param {string} name 객체 이름
 * @param {number} size 지금 크기(지워졌으면 0)
 * @return {Promise<number>} 사용량에 더한 값
 */
export async function recordObjectSize(
  uid: string,
  name: string,
  size: number
): Promise<number> {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const objects = userRef.collection("storage_objects");
  const objectRef = objects.doc(objectDocId(name));
  // 옛 id로 적어 둔 것이 있으면 그 크기를 이어받는다(5차 547). 없으면
  // 읽기 한 번으로 끝난다.
  const legacyRef = objects.doc(legacyObjectDocId(name));
  return db.runTransaction(async (tx) => {
    const [userSnap, objectSnap, legacySnap] = await Promise.all([
      tx.get(userRef),
      tx.get(objectRef),
      tx.get(legacyRef),
    ]);
    const known = objectSnap.exists ? objectSnap : legacySnap;
    const before = (known.data()?.size as number | undefined) ?? 0;
    const delta = size - before;
    if (delta === 0 && known.exists === (size > 0)) {
      // 옛 문서만 있으면 새 id로 옮겨 두고 끝낸다.
      if (!objectSnap.exists && legacySnap.exists) {
        tx.set(objectRef, {name, size: before}, {merge: true});
        tx.delete(legacyRef);
      }
      return 0;
    }

    const storage = userSnap.data()?.storage as
      | {usedBytes?: number; objectCount?: number}
      | undefined;
    const usedBytes = Math.max(0, (storage?.usedBytes ?? 0) + delta);
    const countDelta = (size > 0 ? 1 : 0) - (known.exists ? 1 : 0);
    const objectCount = Math.max(0, (storage?.objectCount ?? 0) + countDelta);

    tx.set(
      userRef,
      {
        storage: {
          usedBytes,
          objectCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true}
    );
    if (size > 0) {
      tx.set(objectRef, {name, size}, {merge: true});
    } else {
      tx.delete(objectRef);
    }
    if (legacySnap.exists && legacyRef.path !== objectRef.path) {
      tx.delete(legacyRef);
    }
    return delta;
  });
}

export const onUserFileUploaded = onObjectFinalized(
  {memory: "256MiB"},
  async (event) => {
    const uid = uidFromObjectName(event.data.name);
    if (!uid) return;
    const size = Number(event.data.size ?? 0);
    if (!Number.isFinite(size) || size < 0) return;
    await recordObjectSize(uid, event.data.name as string, Math.trunc(size));
  }
);

// R2로 옮긴 뒤 Firebase Storage의 옛 사본을 지우면 이 트리거가 온다. 같은
// 키가 R2에 살아 있으면 사용량은 그대로여야 하므로 0으로 적지 않는다.
export const onUserFileDeleted = onObjectDeleted(
  {memory: "512MiB", secrets: r2Secrets},
  async (event) => {
    const uid = uidFromObjectName(event.data.name);
    if (!uid) return;
    const name = event.data.name as string;
    try {
      if (await r2Head(name)) return;
    } catch (error) {
      console.warn("[Storage] R2 head failed, keeping usage", name, error);
      return;
    }
    await recordObjectSize(uid, name, 0);
  }
);


/**
 * 지금 남은 용량. 서버가 센 값과 서버가 정한 단계로만 따진다.
 *
 * @param {string} uid 사용자
 * @return {Promise<Object>} 쓴 양, 한도, 남은 양, 단계
 */
export async function storageStatus(uid: string): Promise<{
  usedBytes: number;
  quotaBytes: number;
  remainingBytes: number;
  tier: SubscriptionTier;
}> {
  const snapshot = await admin.firestore().doc(`users/${uid}`).get();
  const data = snapshot.data();
  const tier = tierFromUserDoc(data);
  const storage = data?.storage as {usedBytes?: number} | undefined;
  const usedBytes = Math.max(0, Math.trunc(storage?.usedBytes ?? 0));
  const quotaBytes = quotaForTier(tier, await loadStorageQuotas());
  return {
    usedBytes,
    quotaBytes,
    remainingBytes: Math.max(0, quotaBytes - usedBytes),
    tier,
  };
}

/**
 * 설정에서 단계별 한도를 읽는다. 없으면 기본값.
 *
 * @return {Promise<Partial<TierLimits>>} 설정값
 */
async function loadStorageQuotas(): Promise<Partial<TierLimits>> {
  try {
    const snapshot = await admin.firestore().doc("config/subscription").get();
    return sanitizeStorage(snapshot.data()?.storage);
  } catch (error) {
    console.error("[Storage] quota config read failed", error);
    return {};
  }
}

/**
 * 올리기 전에 앱이 묻는다. 들어갈 자리가 없으면 까닭을 알려 준다.
 *
 * 앱이 보낸 숫자는 "올리려는 파일 크기"로만 쓴다. 지금 쓴 양과 한도는
 * 서버 값만 본다.
 */
export const checkStorageQuota = onCall(
  {memory: "256MiB", enforceAppCheck: ENFORCE_APP_CHECK},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요해요.");
    }
    const raw = request.data?.bytes;
    const bytes = typeof raw === "number" && Number.isFinite(raw) ?
      Math.max(0, Math.trunc(raw)) :
      0;
    const status = await storageStatus(uid);
    const allowed = bytes <= status.remainingBytes;
    return {...status, bytes, allowed};
  }
);
