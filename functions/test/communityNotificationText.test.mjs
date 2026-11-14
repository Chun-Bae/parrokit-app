// 커뮤니티 알림 글귀(5차).
//
// 전에는 제목 "게시판에 새 댓글이 달렸어요.", 본문 "봄배님이 게시판에 댓글을
// 남겼어요."로 두 줄이 같은 말을 되풀이했고, 정작 어느 글에 달린 댓글인지는
// 알림 어디에도 없었다.
import {test} from "node:test";
import assert from "node:assert/strict";
import {
  buildCommentTitle,
  buildReplyTitle,
  buildCommentBody,
  shortPostTitle,
} from "../lib/communityNotificationText.js";

test("제목은 누가 무엇을 했는지만 말한다", () => {
  assert.equal(buildCommentTitle("board", "봄배"), "봄배님이 댓글을 남겼어요.");
  assert.equal(buildReplyTitle("board", "봄배"), "봄배님이 내 댓글에 답했어요.");
});

test("질문에서는 댓글을 답글이라 부른다(화면과 같은 말)", () => {
  assert.equal(buildCommentTitle("question", "봄배"), "봄배님이 답글을 남겼어요.");
});

test("이름이 없으면 '누군가'", () => {
  assert.equal(buildCommentTitle("board"), "누군가님이 댓글을 남겼어요.");
});

test("본문은 어느 글인지 알려 준다", () => {
  assert.equal(buildCommentBody("board", "안녕하세요."), "'안녕하세요.'에 달렸어요.");
});

test("제목이 없으면 글 종류로 대신한다", () => {
  assert.equal(buildCommentBody("vote", ""), "투표에 달렸어요.");
  assert.equal(buildCommentBody("board", undefined), "게시판에 달렸어요.");
});

test("긴 제목은 30자까지만 쓴다", () => {
  const long = "가".repeat(40);
  assert.equal(shortPostTitle(long), `${"가".repeat(30)}…`);
  assert.equal(shortPostTitle("  짧은 제목  "), "짧은 제목");
});
