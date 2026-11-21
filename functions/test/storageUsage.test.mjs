// 서버가 파일 크기를 어떻게 세는지. 경로 읽기와 단계별 한도.
//
// 실행: functions에서 `npm run test:storage`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {
  quotaForTier,
  sanitizeStorage,
  uidFromObjectName,
  objectDocId,
  legacyObjectDocId,
  DEFAULT_STORAGE_QUOTAS,
} = require("../lib/storageUsage.js");

const GB = 1024 * 1024 * 1024;

test("단계별 한도는 무료 0, 라이트 10GB, 프로 30GB", () => {
  assert.deepEqual(DEFAULT_STORAGE_QUOTAS, {
    free: 0,
    light: 10 * GB,
    plus: 20 * GB,
    pro: 30 * GB,
    max: 80 * GB,
  });
  assert.equal(quotaForTier("free"), 0);
  assert.equal(quotaForTier("light"), 10 * GB);
  assert.equal(quotaForTier("max"), 80 * GB);
  assert.equal(quotaForTier("pro"), 30 * GB);
});

test("설정값이 기본값을 이기고 이상한 값은 버린다", () => {
  assert.equal(quotaForTier("light", {light: 12 * GB}), 12 * GB);
  assert.equal(quotaForTier("pro", {pro: -1}), 30 * GB);
  assert.equal(quotaForTier("pro", {pro: 2 * 1024 * GB}), 30 * GB, "1TB 넘는 값은 버린다");
  assert.deepEqual(sanitizeStorage({light: 1.5}), {});
  assert.deepEqual(sanitizeStorage("5GB"), {});
  assert.deepEqual(sanitizeStorage({free: 0}), {free: 0});
});

test("클립만 센다. 프로필·글 사진은 한도와 상관없다", () => {
  assert.equal(uidFromObjectName("users/uid-1/clips/doc1/video.mp4"), "uid-1");
  assert.equal(uidFromObjectName("users/uid-1/clips/doc1/thumbnail.jpg"), "uid-1");
  // 무료 한도가 0이라, 프로필 사진까지 셌다면 사진을 바꾸는 것만으로 한도를 넘는다.
  assert.equal(uidFromObjectName("users/uid-1/profile.png"), null);
  assert.equal(uidFromObjectName("users/uid-1/posts/p1/a.png"), null);
  assert.equal(uidFromObjectName("caption-inputs/uid-1/a.mp4"), null);
  assert.equal(uidFromObjectName("users/uid-1"), null);
  assert.equal(uidFromObjectName(undefined), null);
});

test("문서 id는 경로마다 다르고 '/'가 없다", () => {
  const id = objectDocId("users/uid-1/clips/a.mp4");
  assert.ok(!id.includes("/"));
  assert.notEqual(id, objectDocId("users/uid-1/clips/b.mp4"));
  assert.equal(id, objectDocId("users/uid-1/clips/a.mp4"), "같은 경로는 같은 id");
  assert.ok(objectDocId("users/uid-1/" + "x".repeat(2000)).length <= 400);
});

// 키는 512자까지 받는데 옛 id는 base64로 바꾼 뒤 400자(입력 300바이트)에서
// 잘랐다. 앞 300바이트가 같은 키들이 한 문서를 써서, 한 파일의 크기가 다른
// 파일 것으로 덮이고 사용량이 실제보다 적게 잡혔다(5차 547).
test("긴 경로도 서로 다른 문서를 쓴다", () => {
  const head = "users/" + "u".repeat(28) + "/clips/" + "a".repeat(260);
  const one = `${head}/video1.mp4`;
  const two = `${head}/video2.mp4`;
  assert.ok(one.length > 300 && one.length <= 512, "허용되는 길이여야 한다");
  assert.notEqual(objectDocId(one), objectDocId(two));
  // 옛 방식은 같은 문서를 썼다. 그 사실을 적어 두어 되돌아오지 않게 한다.
  assert.equal(legacyObjectDocId(one), legacyObjectDocId(two));
});

test("문서 id는 길이가 일정하다", () => {
  const short = objectDocId("users/uid-1/clips/a.mp4");
  const long = objectDocId("users/uid-1/clips/" + "x".repeat(400) + ".mp4");
  assert.equal(short.length, long.length);
});
