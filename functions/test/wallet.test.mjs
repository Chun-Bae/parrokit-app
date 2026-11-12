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

const {ttsCost, videoCost, captionCost} = require("../lib/pricing.js");

test("가격은 앱의 표와 같다", () => {
  // tts_google_models.dart: 100자에 1패롯, 올림, 최소 1
  assert.equal(ttsCost({text: "a".repeat(1), provider: "google"}), 1);
  assert.equal(ttsCost({text: "a".repeat(101), provider: "google"}), 2);
  // tts_elevenlabs_models.dart
  assert.equal(ttsCost({text: "a".repeat(40), provider: "elevenlabs"}), 2);
  assert.equal(
    ttsCost({text: "a".repeat(40), provider: "elevenlabs", modelId: "eleven_turbo_v2_5"}),
    1
  );
  // tts_gemini_models.dart
  assert.equal(ttsCost({text: "a".repeat(120), provider: "gemini"}), 1);
  assert.equal(
    ttsCost({text: "a".repeat(120), provider: "gemini", modelId: "gemini-2.5-pro-preview-tts"}),
    2
  );
  // 모르는 모델은 그 엔진에서 가장 비싼 값
  assert.equal(
    ttsCost({text: "a".repeat(120), provider: "gemini", modelId: "made-up"}),
    2
  );
  assert.equal(ttsCost({text: "", provider: "google"}), 0);
  // video_generation_models.dart
  assert.equal(videoCost("veo-3.1-lite-generate-preview", "720p", 8), 88);
  assert.equal(videoCost("veo-3.1-fast-generate-preview", "1080p", 8), 208);
  assert.equal(videoCost("veo-3.1-generate-preview", "720p", 4), 344);
  assert.equal(videoCost("unknown", "720p", 4), 344);
  // captioning_provider.dart: 10초에 1패롯, 올림
  assert.equal(captionCost(1), 1);
  assert.equal(captionCost(10000), 1);
  assert.equal(captionCost(10001), 2);
  assert.equal(captionCost(0), 0);
});

const {generateKeyPairSync, sign} = require("node:crypto");
const {verifyRewardQuery, creditReward, AD_REWARD_PARROTS, SERVER_CREDIT_TAG} =
  require("../lib/adReward.js");

/** AdMob처럼 서명한 콜백 쿼리를 만든다. */
function signedQuery(privateKey, fields, keyId = "1234") {
  const message = new URLSearchParams(fields).toString();
  const signature = sign("sha256", Buffer.from(message), {key: privateKey, dsaEncoding: "der"})
    .toString("base64url");
  return `${message}&signature=${signature}&key_id=${keyId}`;
}

const adKeys = (() => {
  const {publicKey, privateKey} = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
  return {
    privateKey,
    keys: new Map([["1234", publicKey.export({type: "spki", format: "pem"})]]),
  };
})();

const adFields = (overrides = {}) => ({
  ad_network: "5450213213286189855",
  ad_unit: "1234567890",
  custom_data: SERVER_CREDIT_TAG,
  reward_amount: "3",
  reward_item: "parrot",
  timestamp: "1700000000000",
  transaction_id: "tx123abc",
  user_id: "a",
  ...overrides,
});

test("AdMob 서명이 맞으면 값을 돌려주고, 틀리거나 바뀌면 거절한다", () => {
  const query = signedQuery(adKeys.privateKey, adFields());
  const ok = verifyRewardQuery(query, adKeys.keys);
  assert.equal(ok.userId, "a");
  assert.equal(ok.transactionId, "tx123abc");
  // user_id를 바꿔치기하면 서명이 맞지 않는다
  assert.equal(verifyRewardQuery(query.replace("user_id=a", "user_id=b"), adKeys.keys), null);
  // 모르는 키
  assert.equal(verifyRewardQuery(signedQuery(adKeys.privateKey, adFields(), "999"), adKeys.keys), null);
  // 서명 없음
  assert.equal(verifyRewardQuery(new URLSearchParams(adFields()).toString(), adKeys.keys), null);
});

test("광고 보상은 credit-v1일 때만, 거래마다 한 번만 지급한다", async () => {
  await user("a").set({parrots: 1, crackers: 0});
  const reward = verifyRewardQuery(signedQuery(adKeys.privateKey, adFields()), adKeys.keys);
  assert.equal(await creditReward(reward), true);
  assert.equal(await creditReward(reward), false);
  assert.deepEqual(await balance("a"), {parrots: 1 + AD_REWARD_PARROTS, crackers: 0});

  // 확인만 하는 단계(verify-only)와 user_id 없는 콜백은 지급하지 않는다
  const verifyOnly = verifyRewardQuery(
    signedQuery(adKeys.privateKey, adFields({custom_data: "verify-only", transaction_id: "tx2"})),
    adKeys.keys);
  assert.equal(await creditReward(verifyOnly), false);
  const noUser = {...reward, userId: "", transactionId: "tx3"};
  assert.equal(await creditReward(noUser), false);
  // 없는 사용자에게 문서를 만들지 않는다
  const ghost = {...reward, userId: "ghost", transactionId: "tx4"};
  assert.equal(await creditReward(ghost), false);
  assert.equal((await user("ghost").get()).exists, false);
  assert.deepEqual(await balance("a"), {parrots: 1 + AD_REWARD_PARROTS, crackers: 0});
});
