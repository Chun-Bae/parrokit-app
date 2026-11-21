// 자막 입력 파일 치우기(5차 549).
//
// 언제 올라왔는지 모르는 파일을 0으로 두고 비교해서, 모르는 것을 모두
// 오래된 것으로 보고 지웠다. 목록이 그 값을 안 주는 경우는 타입에도
// 적혀 있다(lastModified?: Date). 지우는 쪽으로 틀리면 방금 올린 영상이
// 작업 도중에 사라진다.
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {expiredCaptionInputs, CAPTION_INPUT_MAX_AGE_MS} = require(
  "../lib/r2Client.js"
);

const NOW = Date.UTC(2026, 10, 22, 4, 0, 0);
const at = (ms) => new Date(NOW - ms);
const HOUR = 60 * 60 * 1000;

test("하루가 지난 것만 고른다", () => {
  const keys = expiredCaptionInputs(
    [
      {key: "old", lastModified: at(25 * HOUR)},
      {key: "fresh", lastModified: at(1 * HOUR)},
      {key: "edge", lastModified: at(CAPTION_INPUT_MAX_AGE_MS)},
    ],
    NOW
  );
  assert.deepEqual(keys, ["old", "edge"]);
});

test("언제 올라왔는지 모르면 두고 간다", () => {
  assert.deepEqual(expiredCaptionInputs([{key: "unknown"}], NOW), []);
  assert.deepEqual(
    expiredCaptionInputs([{key: "bad", lastModified: new Date(NaN)}], NOW),
    []
  );
});

test("빈 목록은 아무것도 고르지 않는다", () => {
  assert.deepEqual(expiredCaptionInputs([], NOW), []);
});

test("두는 기간은 하루다", () => {
  assert.equal(CAPTION_INPUT_MAX_AGE_MS, 24 * HOUR);
});
