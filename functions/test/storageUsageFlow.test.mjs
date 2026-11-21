// 파일이 올라오고 지워질 때 사용량이 어떻게 쌓이는지. Firestore 에뮬레이터 위에서 돈다.
// 실행: functions에서 `npm run test:storageflow`
import {test, beforeEach} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const admin = require("firebase-admin");
admin.initializeApp({projectId: "demo-parrokit"});
const db = admin.firestore();
const {
  recordObjectSize,
  storageStatus,
  DEFAULT_STORAGE_QUOTAS,
  objectDocId,
  legacyObjectDocId,
} = require("../lib/storageUsage.js");

const storageOf = async (uid) =>
  (await db.collection("users").doc(uid).get()).data()?.storage ?? {};

beforeEach(async () => {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-parrokit/databases/(default)/documents`,
    {method: "DELETE"}
  );
  assert.ok(response.ok);
});

test("올린 파일 크기만큼 쌓인다", async () => {
  await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 1000);
  await recordObjectSize("uid-1", "users/uid-1/clips/doc2/video.mp4", 500);

  const storage = await storageOf("uid-1");
  assert.equal(storage.usedBytes, 1500);
  assert.equal(storage.objectCount, 2);
});

test("같은 이벤트가 또 와도 두 번 세지 않는다", async () => {
  await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 1000);
  assert.equal(await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 1000), 0);

  const storage = await storageOf("uid-1");
  assert.equal(storage.usedBytes, 1000);
  assert.equal(storage.objectCount, 1);
});

test("같은 자리에 덮어쓰면 차이만 더한다", async () => {
  await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 1000);
  await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 1500);

  const storage = await storageOf("uid-1");
  assert.equal(storage.usedBytes, 1500);
  assert.equal(storage.objectCount, 1, "파일 수는 그대로");
});

test("지우면 그만큼 줄고, 다시 지워도 더 줄지 않는다", async () => {
  await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 1000);
  await recordObjectSize("uid-1", "users/uid-1/clips/doc2/video.mp4", 500);

  await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 0);
  assert.deepEqual(
    {...(await storageOf("uid-1"))}.usedBytes,
    500
  );

  assert.equal(await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 0), 0);
  const storage = await storageOf("uid-1");
  assert.equal(storage.usedBytes, 500);
  assert.equal(storage.objectCount, 1);
});

test("사람마다 따로 센다", async () => {
  await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 1000);
  await recordObjectSize("uid-2", "users/uid-2/clips/doc1/video.mp4", 300);

  assert.equal((await storageOf("uid-1")).usedBytes, 1000);
  assert.equal((await storageOf("uid-2")).usedBytes, 300);
});

test("남은 용량은 서버가 센 값과 서버가 정한 단계로만 따진다", async () => {
  await db.collection("users").doc("uid-1").set({
    subscription: {tier: "light", status: "active"},
  });
  await recordObjectSize("uid-1", "users/uid-1/clips/doc1/video.mp4", 1000);

  const status = await storageStatus("uid-1");
  assert.equal(status.tier, "light");
  assert.equal(status.usedBytes, 1000);
  // 숫자를 박아 두면 한도를 올릴 때 조용히 깨진다. 실제로 2026-11-21에
  // 라이트가 5GB에서 10GB로 오른 뒤 이 줄만 5GB로 남아 있었다(5차 547).
  assert.equal(status.quotaBytes, DEFAULT_STORAGE_QUOTAS.light);
  assert.equal(status.remainingBytes, status.quotaBytes - 1000);
});

test("무료는 서버에 담을 자리가 없다", async () => {
  await db.collection("users").doc("uid-1").set({nickname: "춘배"});

  const status = await storageStatus("uid-1");
  assert.equal(status.tier, "free");
  assert.equal(status.quotaBytes, 0);
  assert.equal(status.remainingBytes, 0);
});

// 문서 id를 자른 base64에서 해시로 바꿨다(5차 547). 이미 적어 둔 문서를
// 버리면 그만큼의 바이트가 영영 남는다.
test("옛 id로 적어 둔 것을 이어받는다", async () => {
  const name = "users/uid-1/clips/doc1/video.mp4";
  const objects = db.collection("users").doc("uid-1")
    .collection("storage_objects");
  await db.collection("users").doc("uid-1")
    .set({storage: {usedBytes: 1000, objectCount: 1}});
  await objects.doc(legacyObjectDocId(name)).set({name, size: 1000});

  // 같은 크기로 또 와도 두 번 세지 않고, 새 id로 옮겨만 둔다.
  assert.equal(await recordObjectSize("uid-1", name, 1000), 0);
  assert.equal((await storageOf("uid-1")).usedBytes, 1000);
  assert.ok((await objects.doc(objectDocId(name)).get()).exists);
  assert.ok(!(await objects.doc(legacyObjectDocId(name)).get()).exists);

  // 지우면 옛 기록만큼 줄어든다.
  await recordObjectSize("uid-1", name, 0);
  assert.equal((await storageOf("uid-1")).usedBytes, 0);
  assert.equal((await storageOf("uid-1")).objectCount, 0);
});

test("옛 id로 적어 둔 것을 덮어쓰면 차이만 더한다", async () => {
  const name = "users/uid-1/clips/doc2/video.mp4";
  const objects = db.collection("users").doc("uid-1")
    .collection("storage_objects");
  await db.collection("users").doc("uid-1")
    .set({storage: {usedBytes: 1000, objectCount: 1}});
  await objects.doc(legacyObjectDocId(name)).set({name, size: 1000});

  assert.equal(await recordObjectSize("uid-1", name, 1500), 500);
  assert.equal((await storageOf("uid-1")).usedBytes, 1500);
  assert.equal((await storageOf("uid-1")).objectCount, 1);
  assert.ok(!(await objects.doc(legacyObjectDocId(name)).get()).exists);
});
