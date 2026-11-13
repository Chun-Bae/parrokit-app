// 알림 설정에 따라 푸시를 보낼지 정하는 규칙(5차). firebase-admin 없이 돈다.
import {test} from "node:test";
import assert from "node:assert/strict";
import {shouldSendPush} from "../lib/notificationPrefs.js";

test("설정이 없으면 모든 종류를 보낸다", () => {
  for (const type of ["post_comment", "comment_reply", "vote_end"]) {
    assert.equal(shouldSendPush(type, undefined), true);
    assert.equal(shouldSendPush(type, null), true);
    assert.equal(shouldSendPush(type, "x"), true);
  }
});

test("끈 종류만 보내지 않는다", () => {
  const prefs = {postComment: false, commentReply: true};
  assert.equal(shouldSendPush("post_comment", prefs), false);
  assert.equal(shouldSendPush("comment_reply", prefs), true);
  // 키가 없으면 켜진 것으로 본다.
  assert.equal(shouldSendPush("vote_end", prefs), true);
  assert.equal(shouldSendPush("vote_end", {voteEnd: false}), false);
});

test("false가 아닌 값은 켜진 것으로 본다", () => {
  assert.equal(shouldSendPush("post_comment", {postComment: "false"}), true);
  assert.equal(shouldSendPush("post_comment", {postComment: 0}), true);
});
