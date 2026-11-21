// 옛 앱이 Firebase Storage에 올린 파일을 자동으로 R2로 옮긴다.
//
// 앱을 R2로 바꿨지만 옛 버전은 아직 Firebase Storage에 올리고
// firebasestorage.googleapis.com 주소를 Firestore에 적는다. 그 사용자들을
// 기다리지 않도록 서버가 두 단계로 따라간다.
//
// 1. Storage에 users/ 객체가 생기면 같은 키로 R2에 복사한다(mirrorLegacyUpload).
// 2. Firestore 문서에 firebasestorage 주소가 적히면 R2 주소로 바꿔 쓰고
//    Firebase 원본을 지운다(rewrite* 트리거). R2에 아직 없으면 그 자리에서
//    복사한다. 원본 삭제로 오는 onUserFileDeleted는 R2에 같은 키가 있으면
//    사용량을 깎지 않는다.
//
// 덤으로 옛 앱이 프로필 사진을 바꾸면 R2에 남는 옛 사진도 지운다. 옛 앱은
// firebasestorage 주소만 지울 줄 알아서 R2 사진은 그냥 두기 때문이다.
//
// [지우는 법] 사용자가 전부 R2 버전으로 올라와서 Firebase Storage 버킷이
// 몇 주째 비어 있으면 이 파일과 index.ts의 export 한 줄을 지우고
//   firebase functions:delete mirrorLegacyUpload rewriteLegacyUserPhoto \
//     rewriteLegacyPostImages rewriteLegacyClipUrls
// 를 돌린다. 앱 코드는 이 파일에 기대지 않는다. 그 뒤 storage.rules(전부
// 거부)를 배포한다.

import * as admin from "firebase-admin";
import {getStorage} from "firebase-admin/storage";
import {onObjectFinalized} from "firebase-functions/v2/storage";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {
  isOwnedKey,
  legacyFirebaseKeyFromUrl,
  r2Delete,
  r2Head,
  r2KeyFromUrl,
  r2PublicUrl,
  r2PutBytes,
  r2Secrets,
} from "./r2Client";

const TRIGGER_OPTIONS = {memory: "512MiB" as const, secrets: r2Secrets};

/**
 * Firebase Storage 객체를 같은 키로 R2에 복사한다. 이미 같은 크기로 있으면
 * 건너뛴다. 원본이 없으면 false.
 *
 * @param {string} key 객체 키
 * @return {Promise<boolean>} R2에 있게 됐는지
 */
async function ensureInR2(key: string): Promise<boolean> {
  const file = getStorage().bucket().file(key);
  const [exists] = await file.exists();
  if (!exists) {
    return (await r2Head(key)) !== null;
  }
  const [metadata] = await file.getMetadata();
  const size = Number(metadata.size ?? 0);
  const current = await r2Head(key);
  if (current && current.size === size) return true;
  const [bytes] = await file.download();
  await r2PutBytes(
    key,
    Buffer.from(bytes),
    metadata.contentType || "application/octet-stream"
  );
  console.log(`[R2][legacy] copied ${key} (${size} bytes)`);
  return true;
}

/**
 * firebasestorage 주소면 R2로 옮기고 R2 공개 주소를 돌려준다. 그 외는 null.
 *
 * @param {unknown} value 필드값
 * @return {Promise<string | null>} 새 주소
 */
async function migrateUrl(value: unknown): Promise<string | null> {
  if (typeof value !== "string") return null;
  const key = legacyFirebaseKeyFromUrl(value);
  if (!key || !key.startsWith("users/")) return null;
  if (!(await ensureInR2(key))) return null;
  const url = r2PublicUrl(key);
  await getStorage()
    .bucket()
    .file(key)
    .delete({ignoreNotFound: true})
    .catch((error) => {
      console.warn("[R2][legacy] source delete failed", key, error);
    });
  return url;
}

/**
 * 문서의 지정한 필드들에서 firebasestorage 주소를 R2 주소로 바꾼다.
 * 문자열 필드와 문자열 배열 필드 둘 다 본다. 바뀐 게 있을 때만 update한다.
 *
 * @param {FirebaseFirestore.DocumentReference} ref 문서
 * @param {Record<string, unknown>} data 문서 내용
 * @param {string[]} fields 볼 필드
 * @return {Promise<void>}
 */
async function rewriteFields(
  ref: admin.firestore.DocumentReference,
  data: Record<string, unknown>,
  fields: string[]
): Promise<void> {
  const patch: Record<string, unknown> = {};
  for (const field of fields) {
    const value = data[field];
    if (Array.isArray(value)) {
      let changed = false;
      const next: unknown[] = [];
      for (const item of value) {
        const migrated = await migrateUrl(item);
        if (migrated) changed = true;
        next.push(migrated ?? item);
      }
      if (changed) patch[field] = next;
    } else {
      const migrated = await migrateUrl(value);
      if (migrated) patch[field] = migrated;
    }
  }
  if (Object.keys(patch).length === 0) return;
  await ref.update(patch);
  console.log(`[R2][legacy] rewrote ${ref.path}:`, Object.keys(patch));
}

/** 옛 앱 업로드를 R2로 미리 복사해 둔다. 원본은 Firestore 치환 때 지운다. */
export const mirrorLegacyUpload = onObjectFinalized(
  TRIGGER_OPTIONS,
  async (event) => {
    const key = event.data.name;
    if (!key || !key.startsWith("users/")) return;
    try {
      await ensureInR2(key);
    } catch (error) {
      console.error("[R2][legacy] mirror failed", key, error);
    }
  }
);

/**
 * users/{uid}.photoUrl. 옮기고, 옛 앱이 R2 사진을 다른 걸로 바꿨으면 그
 * R2 사진을 지운다(자기 폴더 것만).
 */
export const rewriteLegacyUserPhoto = onDocumentWritten(
  {document: "users/{uid}", ...TRIGGER_OPTIONS},
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const data = after.data() ?? {};
    await rewriteFields(after.ref, data, ["photoUrl"]);

    const beforeUrl = event.data?.before?.data()?.photoUrl;
    const afterUrl = data.photoUrl;
    if (typeof beforeUrl !== "string" || beforeUrl === afterUrl) return;
    const oldKey = r2KeyFromUrl(beforeUrl);
    if (!oldKey || !isOwnedKey(event.params.uid, oldKey)) return;
    if (!oldKey.includes("/profile_")) return;
    await r2Delete(oldKey).catch((error) => {
      console.warn("[R2][legacy] old photo delete failed", oldKey, error);
    });
  }
);

/** posts/{postId}.imageUrls, imageUrl. */
export const rewriteLegacyPostImages = onDocumentWritten(
  {document: "posts/{postId}", ...TRIGGER_OPTIONS},
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    await rewriteFields(after.ref, after.data() ?? {}, [
      "imageUrls",
      "imageUrl",
    ]);
  }
);

/** 보관함 서버 클립의 downloadUrl, thumbnailDownloadUrl. */
export const rewriteLegacyClipUrls = onDocumentWritten(
  {
    document: "users/{uid}/namespaces/library/clips/{clipId}",
    ...TRIGGER_OPTIONS,
  },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    await rewriteFields(after.ref, after.data() ?? {}, [
      "downloadUrl",
      "thumbnailDownloadUrl",
    ]);
  }
);
