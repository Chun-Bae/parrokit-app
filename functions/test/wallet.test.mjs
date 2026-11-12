// 패롯·크래커 함수 테스트. Firestore 에뮬레이터 위에서 콜러블을 직접 부른다.
// 실행: functions에서 `npm run test:wallet`
import {test, beforeEach} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const admin = require("firebase-admin");
admin.initializeApp({projectId: "demo-parrokit"});
const db = admin.firestore();
const {exchangeCurrency} = require("../lib/wallet.js");
const {createQuestion, acceptAnswer} = require("../lib/questions.js");

const call = (fn, uid, data) =>
  fn.run({auth: uid ? {uid, token: {}} : undefined, data, rawRequest: {}});

async function rejects(promise, code) {
  await assert.rejects(promise, (error) => {
    assert.equal(error.code, code, error.message);
    return true;
  });
}

const user = (uid) => db.collection("users").doc(uid);
const balance = async (uid) => {
  const data = (await user(uid).get()).data() ?? {};
  return {parrots: data.parrots ?? 0, crackers: data.crackers ?? 0};
};
const ledger = async (uid) =>
  (await user(uid).collection("wallet_ledger").get()).docs.map((d) => d.id);

beforeEach(async () => {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-parrokit/databases/(default)/documents`,
    {method: "DELETE"}
  );
  assert.ok(response.ok);
});

test("패롯을 크래커로 바꾸면 서버 환율로 바뀌고 장부에 남는다", async () => {
  await user("a").set({parrots: 5, crackers: 0});
  const result = await call(exchangeCurrency, "a", {
    direction: "parrotsToCrackers",
    amount: 2,
    requestId: "req-00001",
  });
  assert.deepEqual(result, {parrots: 3, crackers: 2000});
  assert.deepEqual(await balance("a"), {parrots: 3, crackers: 2000});
  assert.deepEqual(await ledger("a"), ["exchange_req-00001"]);
});

test("같은 요청 id로 다시 부르면 한 번만 바뀐다", async () => {
  await user("a").set({parrots: 5, crackers: 0});
  const data = {direction: "parrotsToCrackers", amount: 1, requestId: "same-req-1"};
  await call(exchangeCurrency, "a", data);
  await call(exchangeCurrency, "a", data);
  assert.deepEqual(await balance("a"), {parrots: 4, crackers: 1000});
});

test("잔액이 모자라거나 단위가 틀리면 아무것도 바뀌지 않는다", async () => {
  await user("a").set({parrots: 1, crackers: 1500});
  await rejects(
    call(exchangeCurrency, "a", {direction: "parrotsToCrackers", amount: 2}),
    "failed-precondition"
  );
  await rejects(
    call(exchangeCurrency, "a", {direction: "crackersToParrots", amount: 1500}),
    "invalid-argument"
  );
  await rejects(
    call(exchangeCurrency, "a", {direction: "parrotsToCrackers", amount: -3}),
    "invalid-argument"
  );
  await rejects(
    call(exchangeCurrency, undefined, {direction: "parrotsToCrackers", amount: 1}),
    "unauthenticated"
  );
  assert.deepEqual(await balance("a"), {parrots: 1, crackers: 1500});
  assert.deepEqual(await ledger("a"), []);
});

test("옛 coins 필드에 있던 패롯도 잔액으로 친다", async () => {
  await user("a").set({coins: 3, crackers: 0});
  await call(exchangeCurrency, "a", {direction: "parrotsToCrackers", amount: 1});
  const data = (await user("a").get()).data();
  assert.equal(data.parrots, 2);
  assert.equal(data.coins, undefined);
});

const question = (overrides = {}) => ({
  id: "q1234567890",
  title: "질문",
  content: "이 문장 어떻게 말해요?",
  category: "Q&A",
  tags: [],
  imageUrls: [],
  authorNickname: "앵무",
  rewardCrackers: 300,
  expireAt: new Date(Date.now() + 3 * 86400000).toISOString(),
  // 앱이 보내도 서버가 무시해야 하는 값
  authorId: "someone-else",
  viewCount: 999,
  questionStatus: "resolved",
  ...overrides,
});

test("질문을 올리면 보상 크래커가 빠지고 글은 서버가 정한 값으로 저장된다", async () => {
  await user("a").set({parrots: 0, crackers: 500});
  const result = await call(createQuestion, "a", {post: question()});
  assert.equal(result.crackers, 200);
  assert.deepEqual(await balance("a"), {parrots: 0, crackers: 200});
  const post = (await db.collection("posts").doc("q1234567890").get()).data();
  assert.equal(post.authorId, "a");
  assert.equal(post.viewCount, 0);
  assert.equal(post.questionStatus, "waiting");
  assert.equal(post.postType, "question");
  assert.equal(post.rewardCrackers, 300);
  assert.deepEqual(await ledger("a"), ["question_q1234567890"]);
  // 같은 글을 다시 올릴 수 없다
  await rejects(call(createQuestion, "a", {post: question()}), "already-exists");
  assert.deepEqual(await balance("a"), {parrots: 0, crackers: 200});
});

test("크래커가 모자라거나 보상이 범위 밖이면 글도 안 생기고 잔액도 그대로다", async () => {
  await user("a").set({parrots: 0, crackers: 200});
  await rejects(call(createQuestion, "a", {post: question()}), "failed-precondition");
  await rejects(
    call(createQuestion, "a", {post: question({rewardCrackers: 150})}),
    "invalid-argument"
  );
  await rejects(
    call(createQuestion, "a", {
      post: question({expireAt: new Date(Date.now() + 30 * 86400000).toISOString()}),
    }),
    "invalid-argument"
  );
  assert.equal((await db.collection("posts").doc("q1234567890").get()).exists, false);
  assert.deepEqual(await balance("a"), {parrots: 0, crackers: 200});
});

async function seedQuestionWithAnswer() {
  await user("asker").set({parrots: 0, crackers: 1000});
  await user("answerer").set({parrots: 0, crackers: 10});
  await call(createQuestion, "asker", {post: question()});
  await db.collection("posts").doc("q1234567890").collection("comments").doc("c1")
    .set({authorId: "answerer", content: "이렇게요", status: "active"});
  await db.collection("posts").doc("q1234567890").collection("comments").doc("mine")
    .set({authorId: "asker", content: "제가 답해요", status: "active"});
}

test("질문 작성자가 채택하면 글의 보상만큼 답변자에게 한 번만 간다", async () => {
  await seedQuestionWithAnswer();
  await call(acceptAnswer, "asker", {postId: "q1234567890", commentId: "c1"});
  assert.deepEqual(await balance("answerer"), {parrots: 0, crackers: 310});
  const post = (await db.collection("posts").doc("q1234567890").get()).data();
  assert.equal(post.questionStatus, "resolved");
  assert.equal(post.acceptedCommentId, "c1");
  const comment = (await db.doc("posts/q1234567890/comments/c1").get()).data();
  assert.equal(comment.isAccepted, true);
  await rejects(
    call(acceptAnswer, "asker", {postId: "q1234567890", commentId: "c1"}),
    "failed-precondition"
  );
  assert.deepEqual(await balance("answerer"), {parrots: 0, crackers: 310});
});

test("작성자가 아니거나 내 답변이면 채택할 수 없다", async () => {
  await seedQuestionWithAnswer();
  await rejects(
    call(acceptAnswer, "answerer", {postId: "q1234567890", commentId: "c1"}),
    "permission-denied"
  );
  await rejects(
    call(acceptAnswer, "asker", {postId: "q1234567890", commentId: "mine"}),
    "failed-precondition"
  );
  await rejects(
    call(acceptAnswer, "asker", {postId: "q1234567890", commentId: "nope"}),
    "not-found"
  );
  assert.deepEqual(await balance("answerer"), {parrots: 0, crackers: 10});
});
