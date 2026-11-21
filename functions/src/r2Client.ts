// Cloudflare R2 클라이언트와 키·주소 도우미.
//
// 사용자 파일(프로필 사진, 글 사진, 클립 영상·썸네일, 자동 자막 원본)은
// Firebase Storage 대신 R2에 둔다. 다운로드 트래픽이 공짜라서다.
// 앱이 부르는 callable은 r2.ts에 있다. 이 파일은 프로젝트 안 다른 모듈을
// 가져오지 않는다(storageUsage.ts가 여기를 쓰므로 순환이 생기면 안 된다).

import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import {getSignedUrl} from "@aws-sdk/s3-request-presigner";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError} from "firebase-functions/v2/https";
import {createWriteStream} from "fs";
import {pipeline} from "stream/promises";
import {Readable} from "stream";

const r2AccessKeyId = defineSecret("R2_ACCESS_KEY_ID");
const r2SecretAccessKey = defineSecret("R2_SECRET_ACCESS_KEY");
const r2AccountId = defineString("R2_ACCOUNT_ID");
const r2Bucket = defineString("R2_BUCKET");
// 공개 읽기 주소. 버킷 Settings → Public access에서 켠 r2.dev 주소나
// 커스텀 도메인. 끝에 슬래시 없음.
const r2PublicBaseUrl = defineString("R2_PUBLIC_BASE_URL", {default: ""});

/** R2를 쓰는 함수는 onCall 옵션에 이 시크릿을 넣는다. */
export const r2Secrets = [r2AccessKeyId, r2SecretAccessKey];

/** 한 파일 상한. storage.rules의 isReasonableSize와 같다. */
export const MAX_OBJECT_BYTES = 512 * 1024 * 1024;
export const UPLOAD_URL_TTL_SECONDS = 15 * 60;
export const DOWNLOAD_URL_TTL_SECONDS = 60 * 60;

let client: S3Client | null = null;

/**
 * S3 호환 클라이언트. 시크릿은 실행 시점에만 읽을 수 있어서 늦게 만든다.
 *
 * @return {S3Client} 클라이언트
 */
export function r2Client(): S3Client {
  if (!client) {
    client = new S3Client({
      region: "auto",
      endpoint: `https://${r2AccountId.value()}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: r2AccessKeyId.value(),
        secretAccessKey: r2SecretAccessKey.value(),
      },
    });
  }
  return client;
}

/**
 * 객체 키의 공개 주소.
 *
 * @param {string} key 객체 키
 * @return {string} 주소
 */
export function r2PublicUrl(key: string): string {
  const base = r2PublicBaseUrl.value().replace(/\/+$/, "");
  if (!base) {
    throw new HttpsError(
      "failed-precondition",
      "서버 저장소 공개 주소가 아직 설정되지 않았어요."
    );
  }
  return `${base}/${key.split("/").map(encodeURIComponent).join("/")}`;
}

/**
 * 공개 주소에서 객체 키를 되찾는다. 우리 주소가 아니면 null.
 *
 * @param {string} url 주소
 * @return {string | null} 키
 */
export function r2KeyFromUrl(url: string): string | null {
  const base = r2PublicBaseUrl.value().replace(/\/+$/, "");
  if (!base || !url.startsWith(base + "/")) return null;
  const rest = url.slice(base.length + 1).split(/[?#]/)[0];
  try {
    return rest.split("/").map(decodeURIComponent).join("/");
  } catch {
    return null;
  }
}

/**
 * 옛 Firebase Storage 다운로드 URL에서 객체 이름을 읽는다.
 *
 * @param {string} url 주소
 * @return {string | null} 객체 이름
 */
export function legacyFirebaseKeyFromUrl(url: string): string | null {
  const match = url.match(
    /^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/[^/]+\/o\/([^?]+)/
  );
  if (!match) return null;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}

/**
 * 객체 키가 이 사용자 것인지. users/{uid}/... 와 caption-inputs/{uid}/...만
 * 허용한다. storage.rules와 같은 경계다.
 *
 * @param {string} uid 사용자
 * @param {string} key 객체 키
 * @return {boolean} 소유 여부
 */
export function isOwnedKey(uid: string, key: string): boolean {
  if (!key || key.length > 512) return false;
  if (key.includes("..") || key.includes("//") || key.startsWith("/")) {
    return false;
  }
  for (const char of key) {
    const code = char.charCodeAt(0);
    if (code < 0x20 || code === 0x7f) return false;
  }
  const parts = key.split("/");
  if (parts.length < 3 || parts[1] !== uid) return false;
  if (parts[parts.length - 1] === "") return false;
  return parts[0] === "users" || parts[0] === "caption-inputs";
}

/**
 * 객체 크기. 없으면 null.
 *
 * @param {string} key 객체 키
 * @return {Promise<Object | null>} {size, contentType} 또는 null
 */
export async function r2Head(
  key: string
): Promise<{size: number; contentType?: string} | null> {
  try {
    const head = await r2Client().send(
      new HeadObjectCommand({Bucket: r2Bucket.value(), Key: key})
    );
    return {
      size: Number(head.ContentLength ?? 0),
      contentType: head.ContentType,
    };
  } catch (error) {
    const status = (error as {$metadata?: {httpStatusCode?: number}})
      .$metadata?.httpStatusCode;
    if (status === 404) return null;
    throw error;
  }
}

/**
 * 객체를 지운다. 없어도 조용히 지나간다.
 *
 * @param {string} key 객체 키
 * @return {Promise<void>}
 */
export async function r2Delete(key: string): Promise<void> {
  await r2Client().send(
    new DeleteObjectCommand({Bucket: r2Bucket.value(), Key: key})
  );
}

/**
 * 한 사람이 자막 입력에 한꺼번에 둘 수 있는 양(5차 550).
 *
 * caption-inputs는 클립이 아니라서 저장 한도(users/{uid}.storage)를 타지
 * 않는다. r2SignUpload도 uidFromObjectName이 null이라 검사를 건너뛴다.
 * 그래서 서버 저장이 0인 무료 사용자도 512MB짜리를 몇 개든 올릴 수 있었고,
 * 앱은 올린 뒤 지우지 않아 하루 한 번 도는 청소를 기다려야 했다.
 *
 * 자막 한 번에 원본 하나를 올린다. 2GB면 끝나지 않은 작업 스무 번쯤
 * 들어가므로 쓰는 데 걸리지 않는다.
 */
export const CAPTION_INPUT_MAX_PENDING_BYTES = 2 * 1024 * 1024 * 1024;

/**
 * 자막 입력을 더 올릴 수 있는지(5차 550).
 *
 * @param {Array} held 지금 두고 있는 것
 * @param {number} nextBytes 이번에 올릴 양
 * @param {number} maxBytes 한꺼번에 둘 수 있는 양
 * @return {boolean} 넘치면 true
 */
export function captionInputsFull(
  held: Array<{size: number}>,
  nextBytes: number,
  maxBytes: number = CAPTION_INPUT_MAX_PENDING_BYTES
): boolean {
  let sum = 0;
  for (const object of held) {
    if (Number.isFinite(object.size) && object.size > 0) sum += object.size;
  }
  return sum + nextBytes > maxBytes;
}

/** 자막 입력 파일을 얼마나 두는지. 하루. */
export const CAPTION_INPUT_MAX_AGE_MS = 24 * 60 * 60 * 1000;

/**
 * 지울 자막 입력 파일을 고른다(5차 549).
 *
 * 언제 올라왔는지 모르는 파일은 **두고 간다**. 전에는 lastModified가
 * 없으면 0으로 두고 비교해서, 모르는 파일을 모두 오래된 것으로 보고
 * 지웠다. 목록이 그 값을 안 주는 경우는 타입에도 적혀 있다
 * (lastModified?: Date). 지우는 쪽으로 틀리면 사용자가 방금 올린 영상이
 * 작업 도중에 사라진다. 하루 더 남는 쪽이 싸다.
 *
 * @param {Array} objects 목록
 * @param {number} nowMs 지금
 * @param {number} maxAgeMs 두는 기간
 * @return {string[]} 지울 키
 */
export function expiredCaptionInputs(
  objects: Array<{key: string; lastModified?: Date}>,
  nowMs: number,
  maxAgeMs: number = CAPTION_INPUT_MAX_AGE_MS
): string[] {
  const cutoff = nowMs - maxAgeMs;
  const out: string[] = [];
  for (const object of objects) {
    const modified = object.lastModified?.getTime();
    if (modified === undefined || !Number.isFinite(modified)) continue;
    if (modified > cutoff) continue;
    out.push(object.key);
  }
  return out;
}

/**
 * 접두사 아래 객체를 전부 나열한다(키, 크기, 마지막 수정).
 *
 * @param {string} prefix 접두사
 * @return {Promise<Array<Object>>} 객체 목록
 */
export async function r2List(
  prefix: string
): Promise<Array<{key: string; size: number; lastModified?: Date}>> {
  const out: Array<{key: string; size: number; lastModified?: Date}> = [];
  let token: string | undefined;
  do {
    const page = await r2Client().send(
      new ListObjectsV2Command({
        Bucket: r2Bucket.value(),
        Prefix: prefix,
        ContinuationToken: token,
      })
    );
    for (const item of page.Contents ?? []) {
      if (!item.Key) continue;
      out.push({
        key: item.Key,
        size: Number(item.Size ?? 0),
        lastModified: item.LastModified,
      });
    }
    token = page.IsTruncated ? page.NextContinuationToken : undefined;
  } while (token);
  return out;
}

/**
 * 객체를 파일로 받는다.
 *
 * @param {string} key 객체 키
 * @param {string} destination 저장할 경로
 * @return {Promise<void>}
 */
export async function r2DownloadToFile(
  key: string,
  destination: string
): Promise<void> {
  const object = await r2Client().send(
    new GetObjectCommand({Bucket: r2Bucket.value(), Key: key})
  );
  if (!object.Body) {
    throw new Error(`R2 object has no body: ${key}`);
  }
  await pipeline(object.Body as Readable, createWriteStream(destination));
}

/**
 * 서버가 직접 객체를 올린다(생성 영상처럼 서버가 만든 파일).
 *
 * @param {string} key 객체 키
 * @param {Buffer} body 내용
 * @param {string} contentType MIME 타입
 * @return {Promise<void>}
 */
export async function r2PutBytes(
  key: string,
  body: Buffer,
  contentType: string
): Promise<void> {
  await r2Client().send(
    new PutObjectCommand({
      Bucket: r2Bucket.value(),
      Key: key,
      Body: body,
      ContentType: contentType,
    })
  );
}

/**
 * 올리기용 presigned PUT 주소.
 *
 * @param {string} key 객체 키
 * @param {string} contentType 앱이 같은 값으로 Content-Type을 보내야 한다
 * @return {Promise<string>} 주소
 */
export async function r2PresignPut(
  key: string,
  contentType: string
): Promise<string> {
  return getSignedUrl(
    r2Client(),
    new PutObjectCommand({
      Bucket: r2Bucket.value(),
      Key: key,
      ContentType: contentType,
    }),
    {expiresIn: UPLOAD_URL_TTL_SECONDS}
  );
}

/**
 * 읽기용 presigned GET 주소. 공개 주소가 없는 경로(caption-inputs)나
 * 공개 주소를 아직 못 쓰는 때에 쓴다.
 *
 * @param {string} key 객체 키
 * @return {Promise<string>} 주소
 */
export async function r2PresignGet(key: string): Promise<string> {
  return getSignedUrl(
    r2Client(),
    new GetObjectCommand({Bucket: r2Bucket.value(), Key: key}),
    {expiresIn: DOWNLOAD_URL_TTL_SECONDS}
  );
}

