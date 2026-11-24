// 광고 보상 콜백의 서명 확인. 돈(패롯)이 걸린 자리라 서명이 조금이라도
// 어긋나면 받아들이지 않아야 한다.
//
// 실행: functions에서 `npm run test:adreward`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {readFileSync} from "node:fs";
import {generateKeyPairSync, sign, createPublicKey} from "node:crypto";

const require = createRequire(import.meta.url);
const {verifyRewardQuery, verifyRewardDetail, messageVariants,
  matchingVariant, redactMessage} = require("../lib/adReward.js");

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

// 실패 까닭이 한 줄로만 찍혀 어디서 걸렸는지 알 수 없었다. 기기에서 온
// 진짜 콜백이 거절되는데 콘솔 테스트 버튼은 통과했다(5차 568).
test("서명 파라미터가 없으면 그렇게 말한다", () => {
  const detail = verifyRewardDetail("ad_unit=1&user_id=u", new Map());
  assert.equal(detail.reward, null);
  assert.equal(detail.reason, "no-signature-param");
  assert.deepEqual(detail.names, ["ad_unit", "user_id"]);
});

test("모르는 key_id면 그렇게 말한다", () => {
  const detail = verifyRewardDetail(
    "ad_unit=1&signature=abc&key_id=99",
    new Map([["3335741209", "pem"]])
  );
  assert.equal(detail.reason, "unknown-key-id");
  assert.equal(detail.keyId, "99");
  assert.deepEqual(detail.knownKeyIds, ["3335741209"]);
});

test("까닭에 값은 담지 않는다", () => {
  const detail = verifyRewardDetail(
    "user_id=secret-uid&signature=zzz&key_id=99",
    new Map()
  );
  const text = JSON.stringify(detail);
  assert.ok(!text.includes("secret-uid"));
  assert.ok(!text.includes("zzz"));
});

// 받은 그대로가 맞는 것이 정상이다. 앞단이 퍼센트 인코딩의 대소문자를
// 바꾸거나 공백 표기를 손대면 바이트가 달라져 서명이 깨진다(5차 568).
test("꼴 목록에 중복이 없다", () => {
  const plain = messageVariants("a=1&b=2");
  // 바꿀 것이 없으면 한 꼴뿐이다.
  assert.equal(plain.length, 1);
  assert.equal(plain[0].name, "raw");

  const encoded = messageVariants("a=%2f&b=x+y");
  const names = encoded.map((one) => one.name);
  assert.ok(names.includes("raw"));
  assert.ok(names.includes("upper-percent"));
  assert.ok(names.includes("plus-as-%20"));
});

test("퍼센트 대소문자를 바꾼 꼴을 만든다", () => {
  const got = messageVariants("x=%2f%3A");
  const upper = got.find((one) => one.name === "upper-percent");
  assert.equal(upper.text, "x=%2F%3A");
  const lower = got.find((one) => one.name === "lower-percent");
  assert.equal(lower.text, "x=%2f%3a");
});

test("받은 그대로 맞으면 raw라고 말한다", () => {
  const message = "ad_unit=1&user_id=u";
  const signature = sign(
    "sha256",
    Buffer.from(message, "utf8"),
    {key: privateKey, dsaEncoding: "der"}
  ).toString("base64url");
  assert.equal(matchingVariant(message, signature, pem), "raw");
});

// 꼴을 여럿 보는 것이 느슨해지는 것은 아니다.
test("서명이 틀리면 어떤 꼴로도 지나가지 않는다", () => {
  const signature = sign(
    "sha256",
    Buffer.from("다른 글", "utf8"),
    {key: privateKey, dsaEncoding: "der"}
  ).toString("base64url");
  assert.equal(matchingVariant("x=%2f", signature, pem), null);
});

test("퍼센트 대소문자만 다른 원문도 받아 준다", () => {
  // AdMob이 %2F로 서명했는데 앞단이 %2f로 바꿔 보낸 꼴.
  const signed = "custom_data=verify-only&user_id=%2FU";
  const received = "custom_data=verify-only&user_id=%2fU";
  const signature = sign(
    "sha256",
    Buffer.from(signed, "utf8"),
    {key: privateKey, dsaEncoding: "der"}
  ).toString("base64url");
  assert.equal(matchingVariant(received, signature, pem), "upper-percent");
});

test("공백을 +로 서명했는데 %20으로 받은 원문도 받아 준다", () => {
  // 보상 항목 이름에 공백이 있으면 AdMob은 `+`로 보내고 그 글자를
  // 서명한다. 앞단이 `%20`으로 바꿔 넘기면 원문이 어긋났다(5차 568).
  const signed = "reward_item=Parrot+3&user_id=U";
  const received = "reward_item=Parrot%203&user_id=U";
  const signature = sign(
    "sha256",
    Buffer.from(signed, "utf8"),
    {key: privateKey, dsaEncoding: "der"}
  ).toString("base64url");
  assert.equal(matchingVariant(received, signature, pem), "%20-as-plus");
});

test("로그에 남길 원문은 user_id 값만 가린다", () => {
  const message = "ad_unit=1&user_id=abc123XYZ&custom_data=verify-only";
  assert.equal(
    redactMessage(message),
    "ad_unit=1&user_id=REDACTED&custom_data=verify-only"
  );
  // 맨 앞에 와도 가린다. 다른 값은 그대로 남아야 어긋난 자리를 찾는다.
  assert.equal(redactMessage("user_id=abc&x=1"), "user_id=REDACTED&x=1");
  assert.equal(redactMessage("x=1&y=2"), "x=1&y=2");
});

test("서명이 안 맞으면 가린 원문을 함께 돌려준다", () => {
  const detail = verifyRewardDetail(
    "user_id=secretuid&reward_item=P&signature=AAAA&key_id=3335741209",
    keys
  );
  assert.equal(detail.reason, "bad-signature");
  assert.ok(!detail.messageRedacted.includes("secretuid"));
  assert.ok(detail.messageRedacted.includes("reward_item=P"));
});

test("콜론을 날것으로 서명했는데 %3A로 받은 원문도 받아 준다", () => {
  // 네이버 로그인 uid는 `naver:<id>`다. AdMob이 인코딩 전 글자로 서명하고
  // `%3A`로 바꿔 보내면 받은 글자로는 안 맞았다(5차 568).
  const signed = "custom_data=verify-only&user_id=naver:abcDEF123";
  const received = "custom_data=verify-only&user_id=naver%3AabcDEF123";
  const signature = sign(
    "sha256",
    Buffer.from(signed, "utf8"),
    {key: privateKey, dsaEncoding: "der"}
  ).toString("base64url");
  assert.equal(matchingVariant(received, signature, pem), "%3A-as-colon");
});

test("성치 않은 퍼센트가 섞여 있어도 터지지 않는다", () => {
  // decodeURIComponent가 던지는 꼴. 다른 꼴로 넘어가야 한다.
  const message = "user_id=%ZZ&x=1";
  const names = messageVariants(message).map((one) => one.name);
  assert.ok(names.includes("raw"));
  const signature = sign(
    "sha256",
    Buffer.from(message, "utf8"),
    {key: privateKey, dsaEncoding: "der"}
  ).toString("base64url");
  assert.equal(matchingVariant(message, signature, pem), "raw");
});

// 앱이 광고를 틀기 직전에 두드려 함수를 미리 깨운다(5차, 사용자 요청).
// 이 길로는 서명을 보지 않으므로 지급도 기록도 일어나지 않아야 한다.
test("warmup은 서명을 보지 않고 204만 돌려준다", () => {
  const src = readFileSync("src/adReward.ts", "utf8");
  const handler = src.slice(src.indexOf("export const admobRewardCallback"));
  const warm = handler.indexOf('req.query.warmup === "1"');
  const verify = handler.indexOf("verifyRewardDetail(");
  assert.ok(warm > -1, "warmup 갈래가 있다");
  assert.ok(verify > -1, "확인 갈래도 그대로 있다");
  assert.ok(warm < verify, "warmup이 확인보다 먼저 빠져나간다");
  assert.match(handler.slice(warm, verify), /res\.status\(204\)[\s\S]*return;/);
});
