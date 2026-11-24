/* eslint-disable require-jsdoc */
// AdMob 보상형 광고의 서버 측 확인(SSV) 콜백.
//
// 전에는 광고를 끝까지 봤다는 앱의 말만 믿고 앱이 패롯을 직접 올렸다. AdMob이
// 광고 시청을 확인하면 이 주소로 서명된 요청을 보낸다. 서명을 Google 공개키로
// 확인하고, 앱이 광고에 실어 보낸 user_id(Firebase uid)에게 지급한다.
// transaction_id를 장부 키로 써서 같은 콜백이 다시 와도 한 번만 지급한다.
//
// 켜는 순서 (거꾸로 하면 이중 지급이나 지급 누락이 생긴다)
// 1. 이 함수를 배포하고 AdMob 콘솔의 보상형 광고 단위에 콜백 URL을 넣는다.
// 2. 앱은 custom_data "verify-only"를 보낸다. 서버는 확인만 하고 기록을
//    남기며, 지급은 지금처럼 앱이 한다. 로그로 콜백이 오는지 본다.
// 3. 앱의 AdService.serverCreditsReward를 true로 바꿔 출시한다. 그 앱은
//    "credit-v1"을 보내고 스스로 지급하지 않는다. 서버가 지급한다.
// user_id가 없는 콜백(SSV를 모르는 옛 앱, 콘솔 테스트)은 확인만 하고 넘긴다.

import * as admin from "firebase-admin";
import {createPublicKey, verify} from "crypto";
import {onRequest} from "firebase-functions/v2/https";
import {applyLedger} from "./wallet";

/** 광고 1회 보상. 앱의 AdService.rewardCoins와 같은 값이다. */
export const AD_REWARD_PARROTS = 3;

/** 앱이 이 값을 custom_data로 보낼 때만 서버가 지급한다. */
export const SERVER_CREDIT_TAG = "credit-v1";

const KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const KEYS_TTL_MS = 12 * 60 * 60 * 1000;

let cachedKeys: {at: number; keys: Map<string, string>} | null = null;

async function fetchKeys(): Promise<Map<string, string>> {
  if (cachedKeys && Date.now() - cachedKeys.at < KEYS_TTL_MS) {
    return cachedKeys.keys;
  }
  const res = await fetch(KEYS_URL);
  if (!res.ok) throw new Error(`verifier keys ${res.status}`);
  const body = (await res.json()) as {keys?: {keyId: number; pem: string}[]};
  const keys = new Map<string, string>();
  for (const k of body.keys ?? []) keys.set(String(k.keyId), k.pem);
  cachedKeys = {at: Date.now(), keys};
  return keys;
}

export interface VerifiedReward {
  userId: string;
  customData: string;
  transactionId: string;
  adUnit: string;
}

/**
 * 콜백 쿼리 문자열의 서명을 확인한다. 서명 대상은 "&signature=" 앞까지의
 * 원문 그대로다(순서·인코딩을 바꾸면 안 된다). 맞으면 필요한 값을, 틀리면
 * null을 돌려준다.
 * @param {string} rawQuery "?" 뒤의 쿼리 문자열 원문
 * @param {Map<string, string>} keys keyId → PEM 공개키
 * @return {VerifiedReward | null} 확인된 값
 */
/**
 * 서명 대상이 될 수 있는 꼴들. AdMob이 서명한 원문과 우리가 받은 문자열이
 * 어긋나는 자리를 좁히려고 둔다(5차 568).
 *
 * 받은 그대로가 맞는 것이 정상이다. 그런데 앞단(Cloud Run)이 퍼센트
 * 인코딩의 대소문자를 바꾸거나 공백 표기를 손대면 바이트가 달라져 서명이
 * 깨진다. 어느 꼴이 맞았는지 로그로 남겨 원인을 적는다.
 *
 * 꼴을 여럿 보는 것이 느슨해지는 것은 아니다. 어떤 꼴이든 **올바른
 * 서명**이 있어야 지나간다.
 * @param {string} message 받은 그대로의 서명 대상
 * @return {{name: string, text: string}[]} 시도할 꼴들
 */
export function messageVariants(
  message: string
): {name: string; text: string}[] {
  const upperPercent = message.replace(
    /%[0-9a-fA-F]{2}/g,
    (hit) => hit.toUpperCase()
  );
  const lowerPercent = message.replace(
    /%[0-9a-fA-F]{2}/g,
    (hit) => `%${hit.slice(1).toLowerCase()}`
  );
  const plusAsSpace = message.replace(/\+/g, "%20");
  // 반대 방향도 본다. 보상 항목 이름에 공백이 있으면 AdMob은 `+`로 보내고
  // 그 글자를 서명하는데, 앞단이 `%20`으로 바꿔 넘기면 원문이 어긋난다.
  const spaceAsPlus = message.replace(/%20/g, "+");
  // 퍼센트를 되돌린 꼴. 네이버 로그인 uid가 `naver:<id>`라서 user_id에
  // 콜론이 들어간다. AdMob은 인코딩 **전** 글자로 서명하고 보낼 때만
  // `%3A`로 바꿔 주는 것으로 보인다 - 받은 글자로는 영원히 안 맞았다(5차 568).
  const colonRaw = message.replace(/%3[aA]/g, ":");
  let decoded = message;
  try {
    decoded = decodeURIComponent(message);
  } catch {
    // 성치 않은 인코딩이면 되돌리지 않는다. 다른 꼴로 본다.
  }
  const list = [
    {name: "raw", text: message},
    {name: "upper-percent", text: upperPercent},
    {name: "lower-percent", text: lowerPercent},
    {name: "plus-as-%20", text: plusAsSpace},
    {name: "%20-as-plus", text: spaceAsPlus},
    {name: "%3A-as-colon", text: colonRaw},
    {name: "decoded", text: decoded},
  ];
  // 같은 글자가 된 꼴은 한 번만 본다.
  const seen = new Set<string>();
  return list.filter((one) => {
    if (seen.has(one.text)) return false;
    seen.add(one.text);
    return true;
  });
}

/**
 * 서명이 맞는 꼴의 이름. 어느 것도 안 맞으면 null.
 * @param {string} message 받은 그대로의 서명 대상
 * @param {string} signature base64url 서명
 * @param {string} pem 공개키
 * @return {string | null} 맞은 꼴의 이름
 */
export function matchingVariant(
  message: string,
  signature: string,
  pem: string
): string | null {
  let key;
  let sig;
  try {
    key = createPublicKey(pem);
    sig = Buffer.from(signature, "base64url");
  } catch {
    return null;
  }
  for (const one of messageVariants(message)) {
    try {
      const ok = verify(
        "sha256",
        Buffer.from(one.text, "utf8"),
        {key, dsaEncoding: "der"},
        sig
      );
      if (ok) return one.name;
    } catch {
      // 이 꼴은 아니다. 다음 꼴을 본다.
    }
  }
  return null;
}

export function verifyRewardQuery(
  rawQuery: string,
  keys: Map<string, string>
): VerifiedReward | null {
  return verifyRewardDetail(rawQuery, keys).reward;
}

/** 왜 안 맞았는지까지 알려 주는 확인. 로그로 원인을 좁히는 데 쓴다. */
export interface VerifyDetail {
  reward: VerifiedReward | null;
  /** 어디서 걸렸는지. 맞았으면 "ok". */
  reason:
    | "ok"
    | "no-signature-param"
    | "no-signature-value"
    | "unknown-key-id"
    | "bad-signature";
  /** 쿼리에 실려 온 파라미터 이름들. 값은 담지 않는다. */
  names: string[];
  keyId: string;
  /** 지금 들고 있는 공개키 id들. 키가 돌면 여기서 어긋난다. */
  knownKeyIds: string[];
  /** 서명 대상 문자열의 길이. 값은 담지 않는다. */
  messageLength: number;
  /** 서명 대상에 퍼센트 인코딩이 남아 있는지. 디코딩됐으면 서명이 깨진다. */
  messageEncoded: boolean;
  /** 서명 바이트 수. ECDSA DER은 보통 70~72다. */
  signatureBytes: number;
  /** 어느 꼴의 서명 대상이 맞았는지. 못 맞췄으면 빈 글자. */
  variant: string;

  /**
   * 서명 대상 원문에서 user_id 값만 가린 글자. 어느 자리가 어긋나는지
   * 눈으로 비교하려고 둔다. 서명과 user_id는 담지 않는다.
   */
  messageRedacted: string;
}

/**
 * 로그에 남길 서명 원문. user_id 값만 가린다.
 *
 * 나머지(광고 단위, 보상 항목·금액, 시각, 거래 번호)는 민감하지 않고,
 * 어느 글자가 AdMob이 서명한 것과 다른지 보려면 그대로 있어야 한다.
 * @param {string} message 서명 대상 원문
 * @return {string} user_id 값을 가린 글자
 */
export function redactMessage(message: string): string {
  return message.replace(/(^|&)(user_id=)[^&]*/g, "$1$2REDACTED");
}

/**
 * 콜백 쿼리의 서명을 확인하고 걸린 자리를 함께 돌려준다.
 *
 * 실패 까닭이 한 줄로만 찍혀서 어디서 걸렸는지 알 수 없었다. 기기에서
 * 온 진짜 콜백이 거절되는데 콘솔 테스트 버튼은 통과했다(5차 568).
 * 값은 담지 않는다 - 서명과 user_id는 로그에 남기지 않는다.
 * @param {string} rawQuery "?" 뒤의 쿼리 문자열 원문
 * @param {Map<string, string>} keys keyId → PEM 공개키
 * @return {VerifyDetail} 확인 결과와 걸린 자리
 */
export function verifyRewardDetail(
  rawQuery: string,
  keys: Map<string, string>
): VerifyDetail {
  const params = new URLSearchParams(rawQuery);
  const names = [...params.keys()];
  const knownKeyIds = [...keys.keys()];
  const keyId = params.get("key_id") ?? "";
  const cut = rawQuery.indexOf("&signature=");
  const message = cut > 0 ? rawQuery.slice(0, cut) : "";
  const signature = params.get("signature") ?? "";
  const base = {
    reward: null,
    names,
    keyId,
    knownKeyIds,
    variant: "",
    messageRedacted: redactMessage(message),
    messageLength: message.length,
    messageEncoded: message.includes("%"),
    signatureBytes: signature ?
      Buffer.from(signature, "base64url").length :
      0,
  };

  if (cut <= 0) return {...base, reason: "no-signature-param"};
  if (!signature) return {...base, reason: "no-signature-value"};
  const pem = keys.get(keyId);
  if (!pem) return {...base, reason: "unknown-key-id"};

  const matched = matchingVariant(message, signature, pem);
  if (!matched) return {...base, reason: "bad-signature"};
  return {
    reward: {
      userId: params.get("user_id") ?? "",
      customData: params.get("custom_data") ?? "",
      transactionId: params.get("transaction_id") ?? "",
      adUnit: params.get("ad_unit") ?? "",
    },
    reason: "ok",
    names,
    keyId,
    knownKeyIds,
    messageLength: base.messageLength,
    messageEncoded: base.messageEncoded,
    signatureBytes: base.signatureBytes,
    messageRedacted: base.messageRedacted,
    variant: matched,
  };
}

/**
 * 확인된 콜백을 처리한다. 지급했으면 true.
 * @param {VerifiedReward} reward 확인된 값
 * @return {Promise<boolean>} 이번에 지급했는지
 */
export async function creditReward(reward: VerifiedReward): Promise<boolean> {
  if (!reward.userId || reward.customData !== SERVER_CREDIT_TAG) return false;
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(reward.transactionId)) return false;
  if (reward.userId.includes("/")) return false;
  // 없는 사용자에게 문서를 새로 만들지 않는다.
  const user = await admin.firestore().collection("users")
    .doc(reward.userId).get();
  if (!user.exists) return false;
  const result = await applyLedger(
    reward.userId,
    {parrots: AD_REWARD_PARROTS},
    {
      key: `ad_${reward.transactionId}`,
      reason: "ad_reward",
      meta: {adUnit: reward.adUnit, transactionId: reward.transactionId},
    }
  );
  return result.applied;
}

/**
 * 기본값 256MiB로는 요청을 처리한 직후 넘쳤다 - 콜백마다 인스턴스가 죽어
 * 다음 콜백이 12초 콜드 스타트를 맞았다(5차 568).
 *
 * 이 함수가 무거운 게 아니다. index.ts가 함수 전부를 한 컨테이너에 모아
 * 불러오므로, 광고 콜백 하나도 genkit·@aws-sdk·음성 합성 SDK를 같이 지고
 * 일어난다. 모듈 로딩만으로 258~262MiB를 썼다. 다른 함수들은 이미 512MiB다.
 */
const OPTIONS = {memory: "512MiB" as const};

export const admobRewardCallback = onRequest(OPTIONS, async (req, res) => {
  const url = req.originalUrl ?? req.url ?? "";
  const rawQuery = url.includes("?") ? url.slice(url.indexOf("?") + 1) : "";
  let detail: VerifyDetail;
  try {
    detail = verifyRewardDetail(rawQuery, await fetchKeys());
  } catch (error) {
    // 공개키를 못 받았으면 AdMob이 다시 보내도록 500을 준다.
    console.error("[AdReward] 공개키를 받지 못했다", error);
    res.status(500).send("keys unavailable");
    return;
  }
  const reward = detail.reward;
  if (!reward) {
    // 까닭과 실려 온 파라미터 이름까지 적는다. 값은 담지 않는다.
    console.warn(
      "[AdReward] 서명이 맞지 않는 요청",
      JSON.stringify({
        reason: detail.reason,
        names: detail.names,
        keyId: detail.keyId,
        knownKeyIds: detail.knownKeyIds,
        messageLength: detail.messageLength,
        messageEncoded: detail.messageEncoded,
        signatureBytes: detail.signatureBytes,
        variant: detail.variant,
        // 원문을 어느 쪽에서 얻었는지. 둘이 다르면 그쪽이 범인이다.
        sameUrl: req.originalUrl === req.url,
        // user_id 값만 가린 서명 원문. 어긋나는 자리를 눈으로 찾는다.
        message: detail.messageRedacted,
      })
    );
    res.status(400).send("invalid signature");
    return;
  }
  try {
    const credited = await creditReward(reward);
    console.log(
      "[AdReward] 확인됨",
      JSON.stringify({
        user: reward.userId ? "set" : "none",
        customData: reward.customData,
        transactionId: reward.transactionId,
        variant: detail.variant,
        credited,
      })
    );
    res.status(200).send("ok");
  } catch (error) {
    console.error("[AdReward] 지급 실패", error);
    res.status(500).send("credit failed");
  }
});
