// 댓글 입력줄의 글. 답글을 쓰는 중이면 '댓글'이 아니라 '답글'이라고 부른다.
//
// 전에는 위에 '○○님에게 답글 남기는 중'이라고 띄워 놓고 입력칸은 '댓글을
// 남겨 보세요'라고 했다. 보내기 툴팁도 화면마다 '댓글 보내기'·'보내기'로
// 달랐다(5차).

/// 입력칸 안내 글.
String commentInputHint({required bool replying}) =>
    replying ? '답글을 남겨 보세요' : '댓글을 남겨 보세요';

/// 보내기 버튼 이름(툴팁).
String commentSendTooltip({required bool replying}) =>
    replying ? '답글 보내기' : '댓글 보내기';

/// 입력칸 위에 띄우는 답글 대상 안내.
String replyingToLabel(String nickname) => '$nickname님에게 답글 남기는 중';

/// 보내기가 꺼진 까닭. 꺼진 단추만 보고는 왜 안 되는지 알 수 없었다(5차 312).
String? commentBlockedReason({required bool hasText, required bool replying}) {
  if (hasText) return null;
  return replying ? '답글을 적어야 보낼 수 있어요.' : '댓글을 적어야 보낼 수 있어요.';
}

/// 못 올렸을 때 알릴 말. 화면마다 달랐다('댓글 등록 실패' 같은 내부 말까지,
/// 5차 398). 답글이면 '답글'이라고 부른다.
String commentSendFailedText({required bool replying}) =>
    replying ? '답글을 올리지 못했어요. 다시 해 주세요.' : '댓글을 올리지 못했어요. 다시 해 주세요.';

/// 닉네임이 없을 때 댓글에 적을 이름.
///
/// 투표 화면만 빈 문자열을 넘겨, 닉네임이 없으면 **이름 없이** 올라갔다
/// (5차 398). 게시판은 '알 수 없음', 질문은 '익명'이라 셋이 다 달랐다.
const String commentUnknownNickname = '알 수 없음';
