// 예문 생성 한도의 기본값. 뜻·발음 채우기(DEFAULT_ASSIST_LIMITS)와 다른 축이다.
//
// 호출 수가 아니라 만든 예문 수를 센다. 한 낱말에 예문 3개를 받으면 3이 줄고,
// 뜻·발음 채우기는 1이 준다. config/sentenceAssist.exampleLimits,
// examplesPerWord로 배포 없이 바꿀 수 있다. 앱의
// subscription_quota.dart가 같은 숫자를 보여 준다.

import {TierLimits} from "./subscriptionTier";

/** 단계별 하루 예문 생성 개수. */
export const DEFAULT_EXAMPLE_LIMITS: TierLimits = {
  // 5개는 쓸 수 없을 만큼 빡빡했다(5차 532, 사용자 결정). 무료는 낱말당
  // 3개까지라 단어 하나를 채우면 3, 두 번째 단어에서 이미 넘쳤다.
  // 10개면 단어 세 개는 채운다. 라이트(30)와는 그대로 3배 차이다.
  free: 10,
  light: 30,
  plus: 80,
  pro: 200,
  max: 500,
};

/** 단계별 낱말당 예문 상한. 절대 상한은 sentenceAssist의 MAX_WORD_EXAMPLES. */
export const DEFAULT_EXAMPLES_PER_WORD: TierLimits = {
  free: 3,
  light: 5,
  plus: 10,
  pro: 10,
  max: 10,
};

/**
 * 패롯으로 사는 예문 몫 한 묶음(5차 532, 사용자 결정).
 *
 * 값은 구독에서 역산했다. 라이트는 월 4,000원에 하루 25개를 더 주므로
 * 예문 1개가 약 5.3원, 패롯 1개가 25~40원이니 '1패롯 = 5개'면 구독과 같은
 * 값이 된다. 구독 자리를 남기려고 그 두 배로 둔다.
 *
 * 광고 1회가 3패롯이므로 광고 한 번 = 한 묶음이다.
 */
export const EXAMPLE_CREDIT_PACK = {
  /** 한 묶음에 드는 패롯. */
  parrots: 3,
  /** 한 묶음으로 받는 예문 몫. */
  credits: 10,
};

/**
 * 뜻·발음 채우기 한 묶음(5차 535, 사용자 요청).
 *
 * 예문과 세는 단위가 다르다 - 이쪽은 호출 횟수다. 구독에서 역산하면
 * 라이트가 월 4,000원에 하루 12번을 더 주므로 1번이 약 11원, 예문 1개
 * (5.3원)의 두 배다. 그래서 같은 3패롯에 절반인 5번을 준다.
 */
export const ASSIST_CREDIT_PACK = {
  /** 한 묶음에 드는 패롯. 예문 묶음과 같다. */
  parrots: 3,
  /** 한 묶음으로 받는 채우기 횟수. */
  credits: 5,
};

/** 한 번에 살 수 있는 묶음 수. 손이 미끄러져 한꺼번에 사는 것을 막는다. */
export const MAX_CREDIT_PACKS_PER_BUY = 10;

/**
 * 이번에 살 묶음 수. 모르는 값이면 1묶음으로 본다.
 *
 * @param {unknown} raw 앱이 보낸 값
 * @return {number} 1 이상 [MAX_CREDIT_PACKS_PER_BUY] 이하
 */
export function readPackCount(raw: unknown): number {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return 1;
  const packs = Math.floor(raw);
  if (packs < 1) return 1;
  return Math.min(packs, MAX_CREDIT_PACKS_PER_BUY);
}

/**
 * 하루 몫과 산 몫에서 각각 얼마를 쓸지 나눈다.
 *
 * 하루 몫부터 쓴다. 날마다 새로 차는 쪽을 먼저 비워야 산 몫이 헛되이
 * 닳지 않는다(지갑의 splitParrotSpend와 같은 원칙).
 *
 * @param {number} dayRoom 오늘 한도에서 남은 수
 * @param {number} credits 사 둔 몫
 * @param {number} want 이번에 쓸 수
 * @return {{fromDay: number, fromCredits: number}} 각각 깎을 수
 */
export function splitExampleSpend(
  dayRoom: number,
  credits: number,
  want: number
): {fromDay: number; fromCredits: number} {
  if (want <= 0) return {fromDay: 0, fromCredits: 0};
  const fromDay = Math.min(Math.max(dayRoom, 0), want);
  const fromCredits = Math.min(Math.max(credits, 0), want - fromDay);
  return {fromDay, fromCredits};
}
