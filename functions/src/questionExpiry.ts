// 마감이 지난 질문을 고르는 규칙. firebase-admin 없이 도는 순수 함수라
// 테스트에서 그대로 부른다(questionExpiry.test.mjs).

/**
 * 마감이 지났는데 채택이 없는 질문인지. 예약 함수와 테스트가 함께 쓴다.
 * @param {Record<string, unknown>} post 질문 글 문서
 * @param {Date} now 지금 시각
 * @return {boolean} 환불 대상이면 true
 */
export function questionNeedsRefund(
  post: Record<string, unknown>,
  now: Date
): boolean {
  if (post.postType !== "question") return false;
  // 채택됐거나 이미 환불한 질문은 건너뛴다.
  if (post.questionStatus !== "waiting") return false;
  const reward = typeof post.rewardCrackers === "number" ?
    Math.trunc(post.rewardCrackers) :
    0;
  if (reward <= 0) return false;
  if (typeof post.expireAt !== "string") return false;
  const expireAt = new Date(post.expireAt);
  if (Number.isNaN(expireAt.getTime())) return false;
  return expireAt.getTime() <= now.getTime();
}
