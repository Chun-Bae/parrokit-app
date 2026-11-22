// 되계산 스크립트가 함수와 같은 규칙으로 적는지(5차 549).
//
// 스크립트는 손으로 돌리는 것이라 테스트가 없었다. 그 사이 함수 쪽
// objectDocId가 '자른 base64'에서 sha256으로 바뀌었는데 스크립트만
// 옛 방식으로 남아 있었다. 다르면 트리거가 이 문서를 못 찾아 사용량이
// 또 어긋난다.
import {test} from "node:test";
import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {readFileSync} from "node:fs";
import {dirname, resolve} from "node:path";
import {fileURLToPath} from "node:url";


const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(
  resolve(here, "../scripts/recount_clip_storage.mjs"),
  "utf8"
);
// storageUsage.ts를 글로 읽는다. 불러오면 Storage 트리거가 버킷 이름을
// 찾느라 터진다.
const serverSrc = readFileSync(
  resolve(here, "../src/storageUsage.ts"),
  "utf8"
);

test("함수와 같은 방식으로 문서 id를 만든다", () => {
  assert.ok(
    src.includes('createHash("sha256").update(o.key).digest("base64url")'),
    "sha256으로 만들어야 한다"
  );
  assert.ok(
    !src.includes('.toString("base64url").slice(0, 400)'),
    "옛 방식이 남아 있다"
  );
});

test("쓰기를 500개 미만으로 나눠 보낸다", () => {
  // Firestore 배치 한도는 500이다. 클립이 많은 사람에서 통째로 터졌다.
  const step = src.match(/i \+= (\d+)\)/);
  assert.ok(step, "배치를 나누는 곳을 찾지 못했다");
  assert.ok(Number(step[1]) < 500, `배치 크기 ${step[1]}`);
});

test("함수 쪽도 sha256을 쓴다", () => {
  assert.ok(
    serverSrc.includes('createHash("sha256").update(name).digest("base64url")'),
    "objectDocId가 sha256이 아니다"
  );
  // 길이가 일정하고 겹치지 않는다는 것만 여기서 확인한다.
  const key = "users/uid-1/clips/doc1/video.mp4";
  const id = createHash("sha256").update(key).digest("base64url");
  assert.equal(id.length, 43);
  assert.ok(!id.includes("/"));
});

// storage_objects를 읽는 곳이 둘인데 한 곳만 옛 id를 보게 고쳤다가
// 회귀를 냈다(5차 552). objectDocId를 sha256으로 바꾼 뒤 r2.ts의
// priorObjectSize가 옛 문서를 못 찾아 0으로 봤고, 그러면 덮어쓰기가
// 새 파일로 잡혀 '덮어쓰기면 지우지 않는다' 갈래를 타지 못했다.
test("storage_objects를 읽는 곳은 모두 옛 id도 본다", () => {
  const readers = ["../src/r2.ts", "../src/storageUsage.ts"];
  for (const path of readers) {
    const code = readFileSync(resolve(here, path), "utf8");
    if (!code.includes('collection("storage_objects")')) continue;
    assert.ok(
      code.includes("legacyObjectDocId("),
      `${path}: 옛 id를 보지 않는다`
    );
  }
});
