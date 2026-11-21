// 패롯으로 예문 생성 몫을 사는 자리(5차 532, 사용자 요청).
//
// 하루 한도는 날마다 새로 찬다(타이머). 여기서 산 몫은 users/{uid}의
// exampleCredits에 쌓이고 **사라지지 않는다**. 쓸 때는 하루 한도부터 쓰고
// 모자랄 때만 깎는다(exampleQuota의 splitExampleSpend).
//
// 패롯을 깎는 것과 몫을 올리는 것은 **한 트랜잭션**이다. 둘 다 users 문서에
// 있어서 applyLedger 한 번으로 끝난다. 따로 했다면 중간에 끊겼을 때 패롯만
// 사라질 수 있었다.
//
// 되돌리기(몫 → 패롯)는 없다. 한 방향이다.

import {onCall, HttpsError} from "firebase-functions/v2/https";
import {ENFORCE_APP_CHECK} from "./appCheck";
import {applyLedger, requestIdOf} from "./wallet";
import {
  ASSIST_CREDIT_PACK,
  EXAMPLE_CREDIT_PACK,
  readPackCount,
} from "./exampleQuota";

/**
 * 패롯을 내고 예문 몫을 받는다.
 *
 * 입력: {packs?: number, requestId?: string}
 * - packs: 묶음 수. 없으면 1, 10을 넘으면 10으로 자른다.
 * - requestId: 같은 값으로 두 번 와도 한 번만 반영한다.
 */
export const buyExampleCredits = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인하면 쓸 수 있어요.");
    }

    const packs = readPackCount(request.data?.packs);
    const parrots = EXAMPLE_CREDIT_PACK.parrots * packs;
    const credits = EXAMPLE_CREDIT_PACK.credits * packs;

    // 구독으로 받은 패롯도 쓸 수 있게 둔다(subFirst 기본값). 그달 안에 쓰라고
    // 준 것이니 먼저 닳는 편이 사용자에게 이롭다.
    const result = await applyLedger(
      uid,
      {parrots: -parrots, exampleCredits: credits},
      {
        key: `example_credits_${requestIdOf(request.data?.requestId)}`,
        reason: "example_credits",
        meta: {packs, parrots, credits},
      }
    );

    return {
      parrots: result.parrots,
      subParrots: result.subParrots,
      exampleCredits: result.exampleCredits,
      // 이번에 실제로 반영됐는지. 같은 requestId가 또 오면 false다.
      applied: result.applied,
      boughtCredits: result.applied ? credits : 0,
      spentParrots: result.applied ? parrots : 0,
    };
  }
);

/**
 * 패롯을 내고 뜻·발음 채우기 몫을 받는다(5차 535).
 *
 * 예문 쪽과 같은 규칙이다. 단위만 '횟수'이고 한 묶음이 5번이다.
 */
export const buyAssistCredits = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인하면 쓸 수 있어요.");
    }

    const packs = readPackCount(request.data?.packs);
    const parrots = ASSIST_CREDIT_PACK.parrots * packs;
    const credits = ASSIST_CREDIT_PACK.credits * packs;

    const result = await applyLedger(
      uid,
      {parrots: -parrots, assistCredits: credits},
      {
        key: `assist_credits_${requestIdOf(request.data?.requestId)}`,
        reason: "assist_credits",
        meta: {packs, parrots, credits},
      }
    );

    return {
      parrots: result.parrots,
      subParrots: result.subParrots,
      assistCredits: result.assistCredits,
      applied: result.applied,
      boughtCredits: result.applied ? credits : 0,
      spentParrots: result.applied ? parrots : 0,
    };
  }
);
