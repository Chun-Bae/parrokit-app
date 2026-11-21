// Cloudflare R2 callable.
//
// R2에는 Firebase Storage 규칙 같은 사용자별 권한이 없다. 그래서 앱은 R2에
// 직접 붙지 않고, 여기 있는 callable이 로그인한 사용자를 확인한 뒤 자기
// 폴더 안에서만 쓸 수 있는 presigned URL을 내준다. 앱은 그 URL로 HTTP PUT
// 한 번 하고 r2FinishUpload를 불러 서버가 크기를 세게 한다.
//
// Storage 트리거(storageUsage.ts)는 R2에서 오지 않으므로 클립 사용량은
// r2FinishUpload / r2DeleteObject가 recordObjectSize로 직접 적는다.

import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {getStorage} from "firebase-admin/storage";
import {ENFORCE_APP_CHECK} from "./appCheck";
import * as admin from "firebase-admin";
import {
  objectDocId,
  recordObjectSize,
  storageStatus,
  uidFromObjectName,
} from "./storageUsage";
import {
  DOWNLOAD_URL_TTL_SECONDS,
  MAX_OBJECT_BYTES,
  UPLOAD_URL_TTL_SECONDS,
  isOwnedKey,
  legacyFirebaseKeyFromUrl,
  r2Delete,
  r2Head,
  r2KeyFromUrl,
  r2List,
  r2PresignGet,
  r2PresignPut,
  r2PublicUrl,
  r2Secrets,
} from "./r2Client";

/**
 * 로그인한 사용자 uid. 없으면 거절.
 *
 * @param {Object | undefined} auth request.auth
 * @return {string} uid
 */
function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요해요.");
  }
  return auth.uid;
}

/**
 * 요청의 path를 읽고 이 사용자 것인지 확인한다.
 *
 * @param {string} uid 사용자
 * @param {unknown} raw 요청값
 * @return {string} 객체 키
 */
function readKey(uid: string, raw: unknown): string {
  const key = typeof raw === "string" ? raw.trim() : "";
  if (!isOwnedKey(uid, key)) {
    throw new HttpsError("permission-denied", "내 파일만 다룰 수 있어요.");
  }
  return key;
}

/**
 * 요청의 contentType. 모양이 이상하면 octet-stream.
 *
 * @param {unknown} raw 요청값
 * @return {string} MIME 타입
 */
function readContentType(raw: unknown): string {
  const value = typeof raw === "string" ? raw.trim() : "";
  if (!/^[\w.+-]+\/[\w.+-]+$/.test(value) || value.length > 100) {
    return "application/octet-stream";
  }
  return value;
}

/**
 * 같은 키로 전에 적어 둔 크기. 덮어쓰기면 그 차이만 한도에 든다.
 *
 * @param {string} uid 사용자
 * @param {string} key 객체 키
 * @return {Promise<number>} 바이트
 */
async function priorObjectSize(uid: string, key: string): Promise<number> {
  const snap = await admin
    .firestore()
    .doc(`users/${uid}/storage_objects/${objectDocId(key)}`)
    .get();
  const size = snap.data()?.size;
  return typeof size === "number" && Number.isFinite(size) ? size : 0;
}

/**
 * 올릴 자리를 내준다. 앱은 {path, contentType, size}를 보내고
 * {uploadUrl, path, publicUrl}을 받는다. 클립 경로면 용량 한도를 먼저 본다.
 */
export const r2SignUpload = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK, secrets: r2Secrets},
  async (request) => {
    const uid = requireUid(request.auth);
    const key = readKey(uid, request.data?.path);
    const contentType = readContentType(request.data?.contentType);
    const rawSize = request.data?.size;
    const size =
      typeof rawSize === "number" && Number.isFinite(rawSize) ?
        Math.trunc(rawSize) :
        -1;
    if (size < 0 || size > MAX_OBJECT_BYTES) {
      throw new HttpsError(
        "invalid-argument",
        "512MB 이하 파일만 올릴 수 있어요."
      );
    }

    if (uidFromObjectName(key)) {
      const status = await storageStatus(uid);
      if (size > status.remainingBytes) {
        throw new HttpsError(
          "resource-exhausted",
          "서버 저장 공간이 모자라요."
        );
      }
    }

    const uploadUrl = await r2PresignPut(key, contentType);
    return {
      uploadUrl,
      path: key,
      contentType,
      publicUrl: r2PublicUrl(key),
      expiresInSeconds: UPLOAD_URL_TTL_SECONDS,
    };
  }
);

/**
 * 올리기가 끝났다고 알린다. 서버가 실제 크기를 읽어 클립 사용량에 더한다.
 */
export const r2FinishUpload = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK, secrets: r2Secrets},
  async (request) => {
    const uid = requireUid(request.auth);
    const key = readKey(uid, request.data?.path);
    const head = await r2Head(key);
    if (!head) {
      throw new HttpsError("not-found", "올린 파일을 찾지 못했어요.");
    }
    if (head.size > MAX_OBJECT_BYTES) {
      await r2Delete(key);
      throw new HttpsError(
        "invalid-argument",
        "512MB 이하 파일만 올릴 수 있어요."
      );
    }
    if (uidFromObjectName(key)) {
      // 서명 때 앱이 말한 크기는 믿지 않는다. 실제 크기로 한도를 다시 본다.
      // 넘치면 올라간 파일을 지우고 거절한다.
      const [status, prior] = await Promise.all([
        storageStatus(uid),
        priorObjectSize(uid, key),
      ]);
      if (head.size - prior > status.remainingBytes) {
        if (prior > 0) {
          // 같은 키를 덮어쓴 경우다. 여기서 지우면 덮어쓰기 전 파일까지
          // 사라지는데 그것은 되살릴 수 없다. 지우지 않고, 실제 크기를
          // 적어 셈만 맞춘 뒤 거절한다. 한도를 조금 넘긴 채로 남지만
          // 사용자가 들고 있던 파일을 잃는 것보다 낫다(5차 515).
          await recordObjectSize(uid, key, head.size);
        } else {
          await r2Delete(key);
        }
        throw new HttpsError(
          "resource-exhausted",
          "서버 저장 공간이 모자라요."
        );
      }
      await recordObjectSize(uid, key, head.size);
    }
    return {
      path: key,
      publicUrl: r2PublicUrl(key),
      size: head.size,
      contentType: head.contentType ?? null,
    };
  }
);

/**
 * 읽기 주소를 내준다. 공개 주소가 있으면 그것, 없으면 presigned GET.
 * R2에 없고 옛 Firebase Storage에 있으면 그쪽 서명 주소를 준다.
 */
export const r2SignDownload = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK, secrets: r2Secrets},
  async (request) => {
    const uid = requireUid(request.auth);
    const key = readKey(uid, request.data?.path);
    if (await r2Head(key)) {
      return {url: await r2PresignGet(key), source: "r2"};
    }
    const legacy = getStorage().bucket().file(key);
    const [exists] = await legacy.exists();
    if (!exists) {
      throw new HttpsError("not-found", "파일을 찾지 못했어요.");
    }
    const [url] = await legacy.getSignedUrl({
      action: "read",
      expires: Date.now() + DOWNLOAD_URL_TTL_SECONDS * 1000,
    });
    return {url, source: "firebase"};
  }
);

/**
 * 파일을 지운다. {path} 또는 {url}. 우리 주소가 아니면 지우지 않고
 * {deleted: false}로 답한다(카카오 프로필 사진 같은 바깥 주소).
 * 옛 Firebase Storage 주소면 그쪽에서 지운다.
 */
export const r2DeleteObject = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK, secrets: r2Secrets},
  async (request) => {
    const uid = requireUid(request.auth);
    const rawPath = request.data?.path;
    const rawUrl = request.data?.url;

    let key: string | null = null;
    let legacyKey: string | null = null;
    if (typeof rawPath === "string" && rawPath.trim()) {
      key = rawPath.trim();
    } else if (typeof rawUrl === "string" && rawUrl.trim()) {
      const url = rawUrl.trim();
      key = r2KeyFromUrl(url);
      if (!key) legacyKey = legacyFirebaseKeyFromUrl(url);
    }

    if (legacyKey) {
      if (!isOwnedKey(uid, legacyKey)) {
        throw new HttpsError("permission-denied", "내 파일만 지울 수 있어요.");
      }
      await getStorage()
        .bucket()
        .file(legacyKey)
        .delete({ignoreNotFound: true});
      return {deleted: true, source: "firebase"};
    }
    if (!key) {
      return {deleted: false, reason: "not-managed"};
    }
    if (!isOwnedKey(uid, key)) {
      throw new HttpsError("permission-denied", "내 파일만 지울 수 있어요.");
    }
    await r2Delete(key);
    if (uidFromObjectName(key)) {
      await recordObjectSize(uid, key, 0);
    }
    return {deleted: true, source: "r2"};
  }
);

/**
 * 자동 자막 원본 청소. generateCaptions가 끝나면 지우지만, 올리고 나서 앱이
 * 죽으면 남는다. 공개 버킷에 사용자 음성이 남아 있으면 안 되니 하루 지난
 * caption-inputs/ 는 매일 지운다.
 */
export const cleanupCaptionInputs = onSchedule(
  {
    schedule: "every day 04:00",
    timeZone: "Asia/Seoul",
    memory: "512MiB",
    secrets: r2Secrets,
  },
  async () => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const objects = await r2List("caption-inputs/");
    let removed = 0;
    for (const object of objects) {
      const modified = object.lastModified?.getTime() ?? 0;
      if (modified > cutoff) continue;
      await r2Delete(object.key);
      removed++;
    }
    console.log(
      `[R2] caption-inputs cleanup: ${removed}/${objects.length} removed`
    );
  }
);
