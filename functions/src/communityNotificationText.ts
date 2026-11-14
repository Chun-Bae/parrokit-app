/* eslint-disable require-jsdoc, max-len */

// 커뮤니티 알림에 들어갈 글귀. admin 없이 도는 순수 함수라 따로 둔다(테스트용).
//
// 전에는 제목 "게시판에 새 댓글이 달렸어요.", 본문 "봄배님이 게시판에 댓글을
// 남겼어요."로 두 줄이 같은 말을 되풀이했고, 정작 어느 글에 달린 댓글인지는
// 알림 어디에도 없었다(5차).

const boardTypeLabelMap: Record<string, string> = {
  // 앱의 커뮤니티 탭 이름과 맞춘다. 전에는 "일반"이라 알림이 "일반에 새
  // 댓글이 달렸어요"가 됐는데 게시판에는 그런 카테고리가 없다.
  board: "게시판",
  question: "질문",
  vote: "투표",
};

// 알림에서 댓글을 뭐라 부를지. 질문 화면은 댓글을 "답글"이라 부른다.
function commentWord(boardType: string): string {
  return boardType === "question" ? "답글" : "댓글";
}

// 글 제목을 알림 한 줄에 들어갈 만큼만 쓴다.
export function shortPostTitle(title?: string): string {
  const trimmed = (title ?? "").trim();
  if (trimmed.length === 0) return "";
  return trimmed.length > 30 ? `${trimmed.slice(0, 30)}…` : trimmed;
}

// 전에는 제목 "게시판에 새 댓글이 달렸어요.", 본문 "봄배님이 게시판에 댓글을
// 남겼어요."였다. 두 줄이 같은 말을 되풀이하면서, 정작 어느 글에 달린
// 댓글인지는 알 수 없었다(알림 목록에 글 제목이 없었다).
export function buildCommentTitle(boardType: string, actorDisplayName?: string): string {
  const actor = actorDisplayName && actorDisplayName.length > 0 ? actorDisplayName : "누군가";
  return `${actor}님이 ${commentWord(boardType)}을 남겼어요.`;
}

export function buildReplyTitle(boardType: string, actorDisplayName?: string): string {
  const actor = actorDisplayName && actorDisplayName.length > 0 ? actorDisplayName : "누군가";
  return `${actor}님이 내 ${commentWord(boardType)}에 답했어요.`;
}

export function buildCommentBody(boardType: string, postTitle?: string): string {
  const title = shortPostTitle(postTitle);
  if (title.length === 0) return `${boardTypeLabelMap[boardType] ?? "게시글"}에 달렸어요.`;
  return `'${title}'에 달렸어요.`;
}

export function buildReplyBody(boardType: string, postTitle?: string): string {
  const title = shortPostTitle(postTitle);
  if (title.length === 0) return `${boardTypeLabelMap[boardType] ?? "게시글"}에 달렸어요.`;
  return `'${title}'에 달렸어요.`;
}
