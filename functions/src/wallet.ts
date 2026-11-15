/* eslint-disable require-jsdoc */
// 패롯·크래커 잔액을 서버에서 바꾸는 곳.
//
// 전에는 앱이 users/{uid}의 parrots·crackers를 직접 썼다. 규칙상 자기
// 문서는 통째로 쓸 수 있어서 사용자가 잔액을 원하는 값으로 바꿀 수 있었다.
// 지급·차감을 여기로 모으고, 모든 변화를 users/{uid}/wallet_ledger에
// 남긴다. 장부 문서 id가 멱등 키라서 같은 요청이 다시 와도 한 번만 반영된다.
//
// 옮기는 순서와 이유는 .claude/review-findings.md의 "패롯과 크래커를 앱이
// 직접 쓴다" 항목에 있다. 마지막 단계에서 규칙으로 앱의 직접 쓰기를 막는다.

import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {appCheckOptions} from "./appCheck";

type Transaction = admin.firestore.Transaction;
type DocumentReference = admin.firestore.DocumentReference;

export interface Balance {
  parrots: number;
  crackers: number;
}

/**
 * 구독으로 매달 받는 패롯. 보통 패롯과 따로 센다.
 *
 * - 쓸 때는 이쪽부터 깎는다(그달 안에 써야 하므로).
 * - 기간이 끝나면 남은 것은 0으로 지운다.
 * - 환전하지 않는다(환전은 보통 패롯만).
 */
export interface FullBalance extends Balance {
  subParrots: number;
}

/**
 * 패롯을 쓸 때 구독 패롯과 보통 패롯에서 각각 얼마를 깎을지 나눈다.
 * 넣는 경우(양수)는 보통 패롯으로 간다.
 *
 * @param {number} subParrots 지금 구독 패롯
 * @param {number} parrotsDelta 바꿀 양(음수면 쓰는 것)
 * @return {{sub: number, normal: number}} 각각 바꿀 양
 */
export function splitParrotSpend(
  subParrots: number,
  parrotsDelta: number
): {sub: number; normal: number} {
  if (parrotsDelta >= 0) return {sub: 0, normal: parrotsDelta};
  const want = -parrotsDelta;
  const fromSub = Math.min(subParrots, want);
  // `|| 0`은 -0이 나오지 않게 한다(장부에 -0을 남기지 않는다).
  return {sub: -fromSub || 0, normal: -(want - fromSub) || 0};
}

export interface Wallet extends FullBalance {
  ref: DocumentReference;
  exists: boolean;
}

/** 잔액을 바꿀 양. subFirst를 false로 두면 구독 패롯을 건드리지 않는다. */
export type WalletDelta = Partial<FullBalance> & {subFirst?: boolean};

export interface LedgerEntry {
  /** 장부 문서 id. 같은 키는 한 번만 반영된다. */
  key: string;
  /** 무엇 때문에 바뀌었는지. 예: exchange, question, accept_answer, tts */
  reason: string;
  meta?: Record<string, unknown>;
}

/** 1패롯 = 1000크래커. 앱의 환전 화면과 같은 값이다. */
export const CRACKERS_PER_PARROT = 1000;

const LEDGER = "wallet_ledger";

function toInt(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ?
    Math.trunc(value) :
    0;
}

/**
 * users/{uid}를 읽는다. 아주 옛 문서는 패롯을 coins에 두었다.
 * @param {Transaction} tx 트랜잭션
 * @param {string} uid 사용자
 * @return {Promise<Wallet>} 잔액과 문서 참조
 */
export async function readWallet(
  tx: Transaction,
  uid: string
): Promise<Wallet> {
  const ref = admin.firestore().collection("users").doc(uid);
  const snapshot = await tx.get(ref);
  const data = snapshot.data() ?? {};
  return {
    ref,
    exists: snapshot.exists,
    parrots: toInt(data.parrots ?? data.coins),
    crackers: toInt(data.crackers),
    subParrots: toInt(data.subParrots),
  };
}

/**
 * 이 키가 이미 장부에 있는지. 트랜잭션의 읽기 단계에서 부른다.
 * @param {Transaction} tx 트랜잭션
 * @param {Wallet} wallet readWallet 결과
 * @param {string} key 장부 문서 id
 * @return {Promise<boolean>} 이미 반영됐으면 true
 */
export async function ledgerExists(
  tx: Transaction,
  wallet: Wallet,
  key: string
): Promise<boolean> {
  return (await tx.get(wallet.ref.collection(LEDGER).doc(key))).exists;
}

/**
 * 잔액을 바꾸고 장부에 남긴다. 트랜잭션의 쓰기 단계에서 부른다.
 * 결과가 음수가 되면 아무것도 쓰지 않고 failed-precondition을 던진다.
 * @param {Transaction} tx 트랜잭션
 * @param {Wallet} wallet readWallet 결과
 * @param {Partial<Balance>} delta 바꿀 양
 * @param {LedgerEntry} entry 장부 기록
 * @return {Balance} 바뀐 뒤 잔액
 */
export function writeWallet(
  tx: Transaction,
  wallet: Wallet,
  delta: WalletDelta,
  entry: LedgerEntry
): FullBalance {
  const parrotsDelta = delta.parrots ?? 0;
  const crackersDelta = delta.crackers ?? 0;
  // 구독 패롯(subParrots)은 따로 넣고(지급), 쓸 때는 이쪽부터 깎는다.
  // 환전처럼 구독 패롯을 쓰면 안 되는 자리는 subFirst를 꺼서 부른다.
  const subDelta = delta.subParrots ?? 0;
  const spend = delta.subFirst === false ?
    {sub: 0, normal: parrotsDelta} :
    splitParrotSpend(wallet.subParrots + subDelta, parrotsDelta);
  const after: FullBalance = {
    parrots: wallet.parrots + spend.normal,
    crackers: wallet.crackers + crackersDelta,
    subParrots: wallet.subParrots + subDelta + spend.sub,
  };
  if (after.parrots < 0 || after.subParrots < 0) {
    throw new HttpsError("failed-precondition", "보유하신 패롯이 부족합니다.");
  }
  if (after.crackers < 0) {
    throw new HttpsError("failed-precondition", "보유하신 크래커가 부족합니다.");
  }
  const now = admin.firestore.FieldValue.serverTimestamp();
  tx.set(
    wallet.ref,
    {
      parrots: after.parrots,
      crackers: after.crackers,
      subParrots: after.subParrots,
      coins: admin.firestore.FieldValue.delete(),
      updatedAt: now,
    },
    {merge: true}
  );
  tx.set(wallet.ref.collection(LEDGER).doc(entry.key), {
    parrots: spend.normal,
    crackers: crackersDelta,
    subParrots: subDelta + spend.sub,
    balanceAfter: after,
    reason: entry.reason,
    meta: entry.meta ?? {},
    at: now,
  });
  return after;
}

/**
 * 한 사람의 잔액만 바꾸는 흔한 경우. 같은 키가 이미 있으면 바꾸지 않고
 * 지금 잔액을 돌려준다.
 * @param {string} uid 사용자
 * @param {Partial<Balance>} delta 바꿀 양
 * @param {LedgerEntry} entry 장부 기록
 * @return {Promise<Object>} 잔액과 이번에 반영했는지(applied)
 */
export async function applyLedger(
  uid: string,
  delta: WalletDelta,
  entry: LedgerEntry
): Promise<FullBalance & {applied: boolean}> {
  return admin.firestore().runTransaction(async (tx) => {
    const wallet = await readWallet(tx, uid);
    if (await ledgerExists(tx, wallet, entry.key)) {
      return {
        parrots: wallet.parrots,
        crackers: wallet.crackers,
        subParrots: wallet.subParrots,
        applied: false,
      };
    }
    return {...writeWallet(tx, wallet, delta, entry), applied: true};
  });
}

/**
 * 앱이 보낸 요청 id를 장부 키에 쓸 수 있는 모양으로 받는다.
 * 없거나 이상하면 새로 만든다(재시도 보호만 없어진다).
 * @param {unknown} value 앱이 보낸 값
 * @return {string} 장부 키에 붙일 id
 */
export function requestIdOf(value: unknown): string {
  if (typeof value === "string" && /^[A-Za-z0-9_-]{8,64}$/.test(value)) {
    return value;
  }
  return admin.firestore().collection("_").doc().id;
}

/**
 * 패롯과 크래커를 바꾼다. 환율은 서버가 정한다. 전에는 앱이 빼는 양과
 * 넣는 양을 둘 다 정해서 보냈다.
 */
export const exchangeCurrency = onCall(appCheckOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const {direction, amount, requestId} = request.data ?? {};
  if (
    typeof amount !== "number" ||
    !Number.isInteger(amount) ||
    amount <= 0 ||
    amount > 100000000
  ) {
    throw new HttpsError("invalid-argument", "환전할 수량을 확인해주세요.");
  }
  let delta: WalletDelta;
  if (direction === "parrotsToCrackers") {
    // 구독으로 받은 패롯은 환전하지 않는다. 보통 패롯이 모자라면 막는다.
    const wallet = await admin.firestore().collection("users").doc(uid).get();
    const own = toInt(wallet.data()?.parrots ?? wallet.data()?.coins);
    if (own < amount) {
      throw new HttpsError(
        "failed-precondition",
        "구독으로 받은 패롯은 환전할 수 없어요. 가진 패롯만큼만 환전해 주세요."
      );
    }
    delta = {
      parrots: -amount,
      crackers: amount * CRACKERS_PER_PARROT,
      subFirst: false,
    };
  } else if (direction === "crackersToParrots") {
    if (amount % CRACKERS_PER_PARROT !== 0) {
      throw new HttpsError(
        "invalid-argument",
        "크래커에서 패롯으로의 환전은 1000 단위로만 가능합니다."
      );
    }
    delta = {parrots: amount / CRACKERS_PER_PARROT, crackers: -amount};
  } else {
    throw new HttpsError("invalid-argument", "환전 방향을 확인해주세요.");
  }
  const result = await applyLedger(uid, delta, {
    key: `exchange_${requestIdOf(requestId)}`,
    reason: "exchange",
    meta: {direction, amount},
  });
  return {parrots: result.parrots, crackers: result.crackers};
});
