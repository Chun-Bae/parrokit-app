// Firebase Storage에 있던 사용자 파일을 Cloudflare R2로 옮기고, Firestore에
// 박힌 firebasestorage.googleapis.com 주소를 R2 공개 주소로 바꾼다.
//
//   cd functions
//   node scripts/migrate_storage_to_r2.mjs              # 보기만(dry-run)
//   node scripts/migrate_storage_to_r2.mjs --apply      # 복사 + 주소 치환
//   node scripts/migrate_storage_to_r2.mjs --delete-source
//       # --apply가 끝난 뒤, R2에 같은 크기로 있는 Storage 원본만 지운다
//
// 필요한 것
// - functions/service-account.json (Admin SDK)
// - functions/.env.parrokit-45126의 R2_ACCOUNT_ID, R2_BUCKET, R2_PUBLIC_BASE_URL
// - R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY: 환경변수에 없으면
//   `firebase functions:secrets:access`로 읽는다.
//
// 같은 키로 복사하므로 users/{uid}/clips/... 의 사용량(storage_objects)은
// 그대로 맞다. 몇 번 돌려도 이미 R2에 같은 크기로 있는 파일은 건너뛴다.

import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import {dirname, resolve} from "node:path";
import {fileURLToPath} from "node:url";
import admin from "firebase-admin";
import {
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import {Upload} from "@aws-sdk/lib-storage";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = resolve(here, "..");
const args = new Set(process.argv.slice(2));
const apply = args.has("--apply");
const deleteSource = args.has("--delete-source");
const mode = deleteSource ? "delete-source" : apply ? "apply" : "dry-run";

function readDotEnv() {
  const out = {};
  // Firebase와 같은 순서: .env 다음 .env.<project>가 덮어쓴다.
  for (const name of [".env", ".env.parrokit-45126"]) {
    let text;
    try {
      text = readFileSync(resolve(functionsDir, name), "utf8");
    } catch {
      continue;
    }
    for (const line of text.split("\n")) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m) out[m[1]] = m[2];
    }
  }
  return out;
}

function secret(name) {
  if (process.env[name]) return process.env[name];
  return execFileSync("firebase", ["functions:secrets:access", name], {
    cwd: functionsDir,
    encoding: "utf8",
  }).trim();
}

const env = {...readDotEnv(), ...process.env};
const accountId = env.R2_ACCOUNT_ID;
const bucketName = env.R2_BUCKET;
const publicBase = (env.R2_PUBLIC_BASE_URL ?? "").replace(/\/+$/, "");
if (!accountId || !bucketName) {
  throw new Error("functions/.env.parrokit-45126에 R2_ACCOUNT_ID, R2_BUCKET이 없다.");
}
if (!publicBase && mode !== "dry-run") {
  throw new Error("functions/.env.parrokit-45126의 R2_PUBLIC_BASE_URL을 먼저 채워라.");
}

const serviceAccount = JSON.parse(
  readFileSync(resolve(functionsDir, "service-account.json"), "utf8")
);
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});

async function findSourceBucket() {
  const projectId = serviceAccount.project_id;
  const candidates = [
    process.env.FIREBASE_STORAGE_BUCKET,
    `${projectId}.firebasestorage.app`,
    `${projectId}.appspot.com`,
  ].filter(Boolean);
  for (const name of candidates) {
    const bucket = admin.storage().bucket(name);
    const [exists] = await bucket.exists().catch(() => [false]);
    if (exists) return bucket;
  }
  throw new Error(`Storage 버킷을 못 찾았다: ${candidates.join(", ")}`);
}

const r2 = new S3Client({
  region: "auto",
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: mode === "dry-run" && !process.env.R2_ACCESS_KEY_ID ?
    {accessKeyId: "dry", secretAccessKey: "run"} :
    {
      accessKeyId: secret("R2_ACCESS_KEY_ID"),
      secretAccessKey: secret("R2_SECRET_ACCESS_KEY"),
    },
});

async function r2Size(key) {
  try {
    const head = await r2.send(new HeadObjectCommand({Bucket: bucketName, Key: key}));
    return Number(head.ContentLength ?? 0);
  } catch (error) {
    if (error?.$metadata?.httpStatusCode === 404) return null;
    throw error;
  }
}

function publicUrl(key) {
  return `${publicBase}/${key.split("/").map(encodeURIComponent).join("/")}`;
}

function legacyKey(url) {
  if (typeof url !== "string") return null;
  const m = url.match(
    /^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/[^/]+\/o\/([^?]+)/
  );
  if (!m) return null;
  try {
    return decodeURIComponent(m[1]);
  } catch {
    return null;
  }
}

// ---- 1. 객체 복사 -----------------------------------------------------------

const source = await findSourceBucket();
console.log(`[${mode}] source bucket: ${source.name} → R2 bucket: ${bucketName}`);

const [files] = await source.getFiles({prefix: "users/"});
const copied = new Set();
let bytesToCopy = 0;
let skipped = 0;
let deleted = 0;

for (const file of files) {
  const key = file.name;
  if (key.endsWith("/")) continue;
  const size = Number(file.metadata.size ?? 0);
  const existing = mode === "dry-run" && !process.env.R2_ACCESS_KEY_ID ?
    null :
    await r2Size(key);

  if (existing === size) {
    copied.add(key);
    if (deleteSource) {
      await file.delete({ignoreNotFound: true});
      deleted++;
      console.log(`  deleted source ${key}`);
    } else {
      skipped++;
    }
    continue;
  }

  if (deleteSource) {
    console.log(`  KEEP (R2에 없거나 크기 다름) ${key}`);
    continue;
  }

  bytesToCopy += size;
  if (!apply) {
    console.log(`  copy ${key} (${size} bytes)`);
    continue;
  }

  const contentType = file.metadata.contentType || "application/octet-stream";
  const upload = new Upload({
    client: r2,
    params: {
      Bucket: bucketName,
      Key: key,
      Body: file.createReadStream(),
      ContentType: contentType,
    },
  });
  await upload.done();
  const after = await r2Size(key);
  if (after !== size) {
    throw new Error(`복사 뒤 크기가 다르다: ${key} ${size} != ${after}`);
  }
  copied.add(key);
  console.log(`  copied ${key} (${size} bytes)`);
}

console.log(
  `objects: ${files.length}, already in R2: ${skipped}, ` +
  `to copy: ${bytesToCopy} bytes, deleted source: ${deleted}`
);

if (deleteSource) {
  process.exit(0);
}

// ---- 2. Firestore 주소 치환 --------------------------------------------------

function rewrite(url) {
  const key = legacyKey(url);
  if (!key) return null;
  if (apply && !copied.has(key)) return null; // R2에 없는 파일은 손대지 않는다
  return publicUrl(key);
}

const db = admin.firestore();
let docsChanged = 0;

async function updateDoc(ref, patch, label) {
  docsChanged++;
  if (!apply) {
    console.log(`  would update ${label}:`, JSON.stringify(patch));
    return;
  }
  await ref.update(patch);
  console.log(`  updated ${label}`);
}

// users/{uid}.photoUrl + Auth photoURL
const users = await db.collection("users").get();
for (const doc of users.docs) {
  const next = rewrite(doc.data().photoUrl);
  if (next) await updateDoc(doc.ref, {photoUrl: next}, `users/${doc.id}.photoUrl`);
}
if (apply) {
  let page = await admin.auth().listUsers(1000);
  for (;;) {
    for (const user of page.users) {
      const next = rewrite(user.photoURL);
      if (next) {
        await admin.auth().updateUser(user.uid, {photoURL: next});
        console.log(`  updated auth photoURL ${user.uid}`);
      }
    }
    if (!page.pageToken) break;
    page = await admin.auth().listUsers(1000, page.pageToken);
  }
}

// posts/{id}.imageUrls[]
const posts = await db.collection("posts").get();
for (const doc of posts.docs) {
  const data = doc.data();
  const patch = {};
  if (Array.isArray(data.imageUrls)) {
    let changed = false;
    const list = data.imageUrls.map((u) => {
      const next = rewrite(u);
      if (next) changed = true;
      return next ?? u;
    });
    if (changed) patch.imageUrls = list;
  }
  const single = rewrite(data.imageUrl);
  if (single) patch.imageUrl = single;
  if (Object.keys(patch).length) await updateDoc(doc.ref, patch, `posts/${doc.id}`);
}

// users/{uid}/namespaces/library/clips/{id}: storagePath 기준으로 주소를 새로 만든다
const clips = await db.collectionGroup("clips").get();
for (const doc of clips.docs) {
  if (!doc.ref.path.includes("/namespaces/library/clips/")) continue;
  const data = doc.data();
  const patch = {};
  for (const [pathField, urlField] of [
    ["storagePath", "downloadUrl"],
    ["thumbnailStoragePath", "thumbnailDownloadUrl"],
  ]) {
    const key = data[pathField];
    const url = data[urlField];
    if (typeof key !== "string" || !key) continue;
    if (!legacyKey(url) && typeof url === "string" && url.startsWith(publicBase)) continue;
    if (apply && !copied.has(key)) continue;
    patch[urlField] = publicUrl(key);
  }
  if (Object.keys(patch).length) await updateDoc(doc.ref, patch, doc.ref.path);
}

console.log(`firestore docs ${apply ? "updated" : "to update"}: ${docsChanged}`);
