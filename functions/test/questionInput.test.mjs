// 질문 글 만들기 입력 검사. 보상 크래커가 걸린 자리라 규칙이 느슨해지면
// 바로 돈 문제가 된다.
//
// 실행: functions에서 `npm run test:questioninput`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {
  buildQuestionDocument,
  MIN_REWARD,
  MAX_REWARD,
  MAX_DEADLINE_MS,
} = require("../lib/questionInput.js");

const NOW = Date.parse("2026-11-16T00:00:00.000Z");
const ID = "abc123XYZ789";

function post(overrides = {}) {
  return {
    id: ID,
    rewardCrackers: 500,
    expireAt: new Date(NOW + 3 * 24 * 60 * 60 * 1000).toISOString(),
    category: "문법",
    title: "이거 왜 이래요?",
    content: "짧은 내용",
    ...overrides,
  };
}

function build(overrides = {}, uid = "me") {
  return buildQuestionDocument({post: post(overrides), uid, now: NOW});
}

function rejects(overrides, message) {
  assert.throws(() => build(overrides), (error) => {
    assert.equal(error.code, "invalid-argument");
    assert.match(error.message, message);
    return true;
  });
}

test("제대로 보낸 글은 서버가 정할 값까지 채워 돌려준다", () => {
  const doc = build();
  assert.equal(doc.id, ID);
  assert.equal(doc.postType, "question");
  assert.equal(doc.authorId, "me");
  assert.equal(doc.authorNickname, "익명", "닉네임을 안 보내면 익명");
  assert.equal(doc.questionStatus, "waiting");
  assert.equal(doc.status, "active");
  assert.equal(doc.acceptedCommentId, null);
  assert.deepEqual(
    [doc.viewCount, doc.likeCount, doc.commentCount, doc.scrapCount],
    [0, 0, 0, 0],
    "숫자는 앱이 보낸 값을 쓰지 않는다"
  );
  assert.equal(doc.reportCount, 0);
  assert.deepEqual(doc.editHistory, []);
  assert.equal(doc.createdAt, new Date(NOW).toISOString());
  assert.equal(doc.hasImage, false);
});

test("앱이 작성자나 숫자를 보내도 서버 값이 이긴다", () => {
  const doc = build({
    authorId: "someone-else",
    likeCount: 999,
    status: "deleted",
    questionStatus: "accepted",
  });
  assert.equal(doc.authorId, "me");
  assert.equal(doc.likeCount, 0);
  assert.equal(doc.status, "active");
  assert.equal(doc.questionStatus, "waiting");
});

test("긴 내용은 50자까지만 미리보기로 자른다", () => {
  const long = "가".repeat(60);
  assert.equal(build({content: long}).snippet, `${"가".repeat(50)}...`);
  const short = "가".repeat(50);
  assert.equal(build({content: short}).snippet, short, "딱 50자면 안 자른다");
});

test("보상 크래커는 100개 단위로 100~5000만 받는다", () => {
  assert.equal(build({rewardCrackers: MIN_REWARD}).rewardCrackers, MIN_REWARD);
  assert.equal(build({rewardCrackers: MAX_REWARD}).rewardCrackers, MAX_REWARD);
  rejects({rewardCrackers: MIN_REWARD - 100}, /보상 크래커/);
  rejects({rewardCrackers: MAX_REWARD + 100}, /보상 크래커/);
  rejects({rewardCrackers: 150}, /보상 크래커/);
  rejects({rewardCrackers: 500.5}, /보상 크래커/);
  rejects({rewardCrackers: "500"}, /보상 크래커/);
  rejects({rewardCrackers: undefined}, /보상 크래커/);
});

test("마감일은 지금보다 뒤, 15일 안이어야 한다", () => {
  rejects({expireAt: new Date(NOW - 1000).toISOString()}, /마감일/);
  rejects({expireAt: new Date(NOW).toISOString()}, /마감일/);
  rejects({expireAt: new Date(NOW + MAX_DEADLINE_MS + 1000).toISOString()},
      /마감일/);
  rejects({expireAt: "어제"}, /마감일/);
  const edge = new Date(NOW + MAX_DEADLINE_MS).toISOString();
  assert.equal(build({expireAt: edge}).expireAt, edge, "딱 15일은 받는다");
});

test("글 id는 영숫자 10~40자만 받는다", () => {
  rejects({id: "short"}, /질문 id/);
  rejects({id: "a".repeat(41)}, /질문 id/);
  rejects({id: "with-dash-0123"}, /질문 id/);
  rejects({id: "../other/path0"}, /질문 id/);
  rejects({id: 12345678901}, /질문 id/);
});

test("사진은 https 주소 10장까지만 받는다", () => {
  const url = "https://example.com/a.jpg";
  const doc = build({imageUrls: [url, url]});
  assert.deepEqual(doc.imageUrls, [url, url]);
  assert.equal(doc.hasImage, true);

  rejects({imageUrls: ["http://example.com/a.jpg"]}, /사진/);
  rejects({imageUrls: ["javascript:alert(1)"]}, /사진/);
  rejects({imageUrls: new Array(11).fill(url)}, /사진/);
  rejects({imageUrls: [123]}, /사진/);
});

test("태그는 10자짜리 20개까지만 받는다", () => {
  assert.deepEqual(build({tags: ["문법", "영어"]}).tags, ["문법", "영어"]);
  assert.deepEqual(build({tags: undefined}).tags, [], "안 보내면 빈 목록");
  rejects({tags: new Array(21).fill("가")}, /태그/);
  rejects({tags: ["가".repeat(11)]}, /태그/);
  rejects({tags: "문법"}, /태그/);
});

test("꼭 있어야 하는 글자는 비면 안 된다", () => {
  rejects({title: "   "}, /제목/);
  rejects({title: undefined}, /제목/);
  rejects({content: ""}, /내용/);
  rejects({category: undefined}, /분류/);
  rejects({title: "가".repeat(201)}, /제목/);
});

test("없어도 되는 글자는 비워 둘 수 있다", () => {
  const doc = build({targetLanguage: undefined, authorAvatarUrl: undefined});
  assert.equal(doc.targetLanguage, null);
  assert.equal(doc.authorAvatarUrl, null);
  assert.equal(build({authorNickname: "춘배"}).authorNickname, "춘배");
});
