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
export function verifyRewardQuery(
  rawQuery: string,
  keys: Map<string, string>
): VerifiedReward | null {
  const cut = rawQuery.indexOf("&signature=");
  if (cut <= 0) return null;
  const message = rawQuery.slice(0, cut);
  const params = new URLSearchParams(rawQuery);
  const signature = params.get("signature") ?? "";
  const keyId = params.get("key_id") ?? "";
  const pem = keys.get(keyId);
  if (!signature || !pem) return null;
  let ok = false;
  try {
    ok = verify(
      "sha256",
      Buffer.from(message, "utf8"),
      {key: createPublicKey(pem), dsaEncoding: "der"},
      Buffer.from(signature, "base64url")
    );
  } catch {
    ok = false;
  }
  if (!ok) return null;
  return {
    userId: params.get("user_id") ?? "",
    customData: params.get("custom_data") ?? "",
    transactionId: params.get("transaction_id") ?? "",
    adUnit: params.get("ad_unit") ?? "",
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

export const admobRewardCallback = onRequest(async (req, res) => {
  const url = req.originalUrl ?? req.url ?? "";
  const rawQuery = url.includes("?") ? url.slice(url.indexOf("?") + 1) : "";
  let reward: VerifiedReward | null = null;
  try {
    reward = verifyRewardQuery(rawQuery, await fetchKeys());
  } catch (error) {
    // 공개키를 못 받았으면 AdMob이 다시 보내도록 500을 준다.
    console.error("[AdReward] 공개키를 받지 못했다", error);
    res.status(500).send("keys unavailable");
    return;
  }
  if (!reward) {
    console.warn("[AdReward] 서명이 맞지 않는 요청");
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
        credited,
      })
    );
    res.status(200).send("ok");
  } catch (error) {
    console.error("[AdReward] 지급 실패", error);
    res.status(500).send("credit failed");
  }
});
