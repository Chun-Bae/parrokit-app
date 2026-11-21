// 클립 저장 용량 집계를 R2의 실제 클립 객체로 되계산한다.
//
// users/{uid}.storage는 클립(users/{uid}/clips/...)만 세야 한다. 그런데
// onUserFileUploaded가 그 필터가 없던 옛 빌드로 남아 있어서 프로필 사진까지
// 셌다(5차 510). 함수를 다시 배포한 뒤 이 스크립트로 숫자를 바로잡는다.
//
//   cd functions
//   node scripts/recount_clip_storage.mjs           # 보기만
//   node scripts/recount_clip_storage.mjs --apply   # 고치기

import {execFileSync} from "node:child_process";
import {createHash} from "node:crypto";
import {readFileSync} from "node:fs";
import {dirname, resolve} from "node:path";
import {fileURLToPath} from "node:url";
import admin from "firebase-admin";
import {S3Client, ListObjectsV2Command} from "@aws-sdk/client-s3";

const here = dirname(fileURLToPath(import.meta.url));
const functionsDir = resolve(here, "..");
const apply = process.argv.includes("--apply");

function readDotEnv() {
  const out = {};
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

const env = {...readDotEnv(), ...process.env};
const sec = (n) =>
  process.env[n] ??
  execFileSync("firebase", ["functions:secrets:access", n], {
    cwd: functionsDir,
    encoding: "utf8",
  }).trim();

const r2 = new S3Client({
  region: "auto",
  endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: sec("R2_ACCESS_KEY_ID"),
    secretAccessKey: sec("R2_SECRET_ACCESS_KEY"),
  },
});

const objects = [];
let token;
do {
  const page = await r2.send(new ListObjectsV2Command({
    Bucket: env.R2_BUCKET,
    Prefix: "users/",
    ContinuationToken: token,
  }));
  for (const o of page.Contents ?? []) {
    if (o.Key) objects.push({key: o.Key, size: Number(o.Size ?? 0)});
  }
  token = page.IsTruncated ? page.NextContinuationToken : undefined;
} while (token);

// 클립만 센다. uidFromObjectName과 같은 규칙이다.
function clipUid(key) {
  const parts = key.split("/");
  if (parts.length < 4 || parts[0] !== "users" || parts[2] !== "clips") {
    return null;
  }
  return parts[1] || null;
}

const byUid = new Map();
for (const o of objects) {
  const uid = clipUid(o.key);
  if (!uid) continue;
  const cur = byUid.get(uid) ?? {bytes: 0, count: 0, keys: []};
  cur.bytes += o.size;
  cur.count += 1;
  cur.keys.push(o);
  byUid.set(uid, cur);
}

admin.initializeApp({
  credential: admin.credential.cert(
    JSON.parse(readFileSync(resolve(functionsDir, "service-account.json"), "utf8"))
  ),
});
const db = admin.firestore();

const users = await db.collection("users").get();
let fixed = 0;
for (const doc of users.docs) {
  const storage = doc.data().storage;
  const actual = byUid.get(doc.id) ?? {bytes: 0, count: 0, keys: []};
  const usedBytes = storage?.usedBytes ?? 0;
  const objectCount = storage?.objectCount ?? 0;
  if (usedBytes === actual.bytes && objectCount === actual.count) continue;

  fixed++;
  console.log(
    `${doc.id}: ${usedBytes}B/${objectCount}개 -> ${actual.bytes}B/${actual.count}개`
  );
  if (!apply) continue;

  // storage_objects도 실제 클립만 남긴다.
  const sub = await doc.ref.collection("storage_objects").get();
  const writes = [];
  for (const d of sub.docs) writes.push((b) => b.delete(d.ref));
  for (const o of actual.keys) {
    // storageUsage.ts의 objectDocId와 같아야 한다(5차 549). 전에는 여기서
    // base64를 400자로 잘랐는데, 함수 쪽은 sha256으로 바뀌었다. 다르면
    // 트리거가 이 문서를 못 찾아 사용량이 또 어긋난다.
    const id = createHash("sha256").update(o.key).digest("base64url");
    writes.push((b) =>
      b.set(doc.ref.collection("storage_objects").doc(id), {
        name: o.key,
        size: o.size,
      })
    );
  }
  writes.push((b) =>
    b.set(
      doc.ref,
      {
        storage: {
          usedBytes: actual.bytes,
          objectCount: actual.count,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      {merge: true}
    )
  );

  // Firestore 배치는 500개까지다. 클립이 많은 사람에서 통째로 터졌다.
  for (let i = 0; i < writes.length; i += 450) {
    const batch = db.batch();
    for (const write of writes.slice(i, i + 450)) write(batch);
    await batch.commit();
  }
}
console.log(apply ? `고친 사용자 ${fixed}명` : `고칠 사용자 ${fixed}명(보기만)`);
