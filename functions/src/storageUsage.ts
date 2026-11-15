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
import {SubscriptionTier} from "./subscriptionEvent";
import {TierLimits} from "./subscriptionTier";

/** 단계별 서버 저장 한도(바이트). config/subscription.storage로 바꿀 수 있다. */
export const DEFAULT_STORAGE_QUOTAS: TierLimits = {
  free: 0,
  light: 5 * 1024 * 1024 * 1024,
  pro: 30 * 1024 * 1024 * 1024,
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
  for (const key of ["free", "light", "pro"] as const) {
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
 * 파일 경로에서 주인을 읽는다. users/{uid}/... 밖은 세지 않는다.
 *
 * @param {string | undefined} name Storage 객체 이름
 * @return {string | null} uid
 */
export function uidFromObjectName(name: string | undefined): string | null {
  if (!name) return null;
  const parts = name.split("/");
  if (parts.length < 3 || parts[0] !== "users") return null;
  return parts[1] || null;
}

/**
 * 객체 이름을 Firestore 문서 id로 쓸 수 있게 바꾼다('/'를 못 쓴다).
 *
 * @param {string} name Storage 객체 이름
 * @return {string} 문서 id
 */
export function objectDocId(name: string): string {
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
  const objectRef = userRef
    .collection("storage_objects")
    .doc(objectDocId(name));
  return db.runTransaction(async (tx) => {
    const [userSnap, objectSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(objectRef),
    ]);
    const before = (objectSnap.data()?.size as number | undefined) ?? 0;
    const delta = size - before;
    if (delta === 0 && objectSnap.exists === (size > 0)) return 0;

    const storage = userSnap.data()?.storage as
      | {usedBytes?: number; objectCount?: number}
      | undefined;
    const usedBytes = Math.max(0, (storage?.usedBytes ?? 0) + delta);
    const countDelta = (size > 0 ? 1 : 0) - (objectSnap.exists ? 1 : 0);
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

export const onUserFileDeleted = onObjectDeleted(
  {memory: "256MiB"},
  async (event) => {
    const uid = uidFromObjectName(event.data.name);
    if (!uid) return;
    await recordObjectSize(uid, event.data.name as string, 0);
  }
);
