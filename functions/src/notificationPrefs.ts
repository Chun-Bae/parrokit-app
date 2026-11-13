/* eslint-disable max-len */

// 커뮤니티 알림 설정(5차). 사용자 문서 users/{uid}.notificationPrefs에 앱이
// 저장한다. 키 이름은 앱 lib/features/community/notification/data/settings/
// notification_prefs.dart와 같아야 한다. 꺼진 종류는 휴대폰 푸시만 보내지 않고
// 알림 목록(users/{uid}/notifications)에는 그대로 남긴다.
//
// firebase-admin을 불러오지 않아 테스트에서 그대로 쓸 수 있다.

export type CommunityNotificationType = "post_comment" | "comment_reply" | "vote_end";

const prefKeyByType: Record<CommunityNotificationType, string> = {
  post_comment: "postComment",
  comment_reply: "commentReply",
  vote_end: "voteEnd",
};

/**
 * 이 종류의 푸시를 보내도 되는지. 설정이 없거나 모양이 다르면 보낸다(예전
 * 사용자는 모두 받았다). 명시적으로 false일 때만 보내지 않는다.
 * @param {CommunityNotificationType} type 알림 종류
 * @param {unknown} prefs users 문서의 notificationPrefs 값
 * @return {boolean} 보내도 되면 true
 */
export function shouldSendPush(type: CommunityNotificationType, prefs: unknown): boolean {
  if (prefs === null || typeof prefs !== "object") return true;
  const value = (prefs as Record<string, unknown>)[prefKeyByType[type]];
  return value !== false;
}
