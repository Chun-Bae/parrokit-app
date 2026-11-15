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
