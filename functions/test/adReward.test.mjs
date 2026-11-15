// 광고 보상 콜백의 서명 확인. 돈(패롯)이 걸린 자리라 서명이 조금이라도
// 어긋나면 받아들이지 않아야 한다.
//
// 실행: functions에서 `npm run test:adreward`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {generateKeyPairSync, sign, createPublicKey} from "node:crypto";

const require = createRequire(import.meta.url);
const {verifyRewardQuery} = require("../lib/adReward.js");

// AdMob이 쓰는 것과 같은 방식(ECDSA P-256, SHA-256, DER 서명).
const {privateKey, publicKey} = generateKeyPairSync("ec", {
  namedCurve: "prime256v1",
});
const pem = publicKey.export({type: "spki", format: "pem"}).toString();
const keys = new Map([["3335741209", pem]]);

/** 서명까지 붙인 콜백 쿼리 문자열을 만든다. */
function signedQuery(message, {keyId = "3335741209", key = privateKey} = {}) {
  const signature = sign("sha256", Buffer.from(message, "utf8"), {
    key,
    dsaEncoding: "der",
  }).toString("base64url");
  return `${message}&signature=${signature}&key_id=${keyId}`;
}

const message =
  "ad_network=5450213213286189855&ad_unit=1234&custom_data=credit-v1" +
  "&reward_amount=3&reward_item=parrot&timestamp=1700000000000" +
  "&transaction_id=abc123&user_id=uid-1";

test("서명이 맞으면 값을 돌려준다", () => {
  const reward = verifyRewardQuery(signedQuery(message), keys);
  assert.ok(reward);
  assert.equal(reward.userId, "uid-1");
  assert.equal(reward.customData, "credit-v1");
  assert.equal(reward.transactionId, "abc123");
  assert.equal(reward.adUnit, "1234");
});

test("내용을 한 글자만 바꿔도 받아들이지 않는다", () => {
  const query = signedQuery(message).replace("user_id=uid-1", "user_id=uid-2");
  assert.equal(verifyRewardQuery(query, keys), null);
});

test("다른 키로 서명하면 받아들이지 않는다", () => {
  const other = generateKeyPairSync("ec", {namedCurve: "prime256v1"});
  const query = signedQuery(message, {key: other.privateKey});
  assert.equal(verifyRewardQuery(query, keys), null);
});

test("모르는 key_id면 받아들이지 않는다", () => {
  const query = signedQuery(message, {keyId: "9999"});
  assert.equal(verifyRewardQuery(query, keys), null);
});

test("서명이 없으면 받아들이지 않는다", () => {
  assert.equal(verifyRewardQuery(message, keys), null);
  assert.equal(verifyRewardQuery("", keys), null);
  assert.equal(verifyRewardQuery("&signature=abc", keys), null);
});

test("서명이 base64가 아니어도 터지지 않는다", () => {
  assert.equal(
    verifyRewardQuery(`${message}&signature=!!!&key_id=3335741209`, keys),
    null
  );
});

test("서명 뒤에 붙인 값은 확인 대상이 아니다(AdMob 규격)", () => {
  // AdMob은 "&signature=" 앞까지만 서명한다. 뒤에 무엇이 붙든 확인에는
  // 쓰이지 않으므로, 앞부분이 그대로라면 통과한다.
  const query = `${signedQuery(message)}&extra=1`;
  const reward = verifyRewardQuery(query, keys);
  assert.ok(reward);
  assert.equal(reward.userId, "uid-1");
});

test("공개키를 읽을 수 없으면 받아들이지 않는다", () => {
  const broken = new Map([["3335741209", "not-a-pem"]]);
  assert.equal(verifyRewardQuery(signedQuery(message), broken), null);
  // 진짜 키는 읽힌다(테스트 자체가 맞는지 확인).
  assert.ok(createPublicKey(pem));
});
