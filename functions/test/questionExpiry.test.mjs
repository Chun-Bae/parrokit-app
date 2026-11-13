// 마감이 지난 질문의 크래커를 돌려줄지 고르는 규칙(5차). admin 없이 돈다.
import {test} from "node:test";
import assert from "node:assert/strict";
import {questionNeedsRefund} from "../lib/questionExpiry.js";

const now = new Date("2026-11-14T09:00:00.000Z");
const base = {
  postType: "question",
  questionStatus: "waiting",
  rewardCrackers: 50,
  expireAt: "2026-11-14T08:00:00.000Z",
};

test("마감이 지나고 채택이 없으면 돌려준다", () => {
  assert.equal(questionNeedsRefund(base, now), true);
});

test("마감 전이면 돌려주지 않는다", () => {
  const future = {...base, expireAt: "2026-11-14T10:00:00.000Z"};
  assert.equal(questionNeedsRefund(future, now), false);
  // 마감 시각과 같으면 지난 것으로 본다.
  const exact = {...base, expireAt: now.toISOString()};
  assert.equal(questionNeedsRefund(exact, now), true);
});

test("채택했거나 이미 돌려준 질문은 건너뛴다", () => {
  for (const status of ["resolved", "expired", "", undefined]) {
    assert.equal(
      questionNeedsRefund({...base, questionStatus: status}, now),
      false
    );
  }
});

test("보상이 없으면 돌려줄 것도 없다", () => {
  for (const reward of [0, -5, undefined, "50", null]) {
    assert.equal(
      questionNeedsRefund({...base, rewardCrackers: reward}, now),
      false
    );
  }
});

test("질문이 아니거나 마감일이 이상하면 건너뛴다", () => {
  assert.equal(questionNeedsRefund({...base, postType: "board"}, now), false);
  for (const expireAt of [undefined, "", "어제", 123, null]) {
    assert.equal(questionNeedsRefund({...base, expireAt}, now), false);
  }
});
