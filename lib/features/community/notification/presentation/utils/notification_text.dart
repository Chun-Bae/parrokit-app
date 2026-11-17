// 저장된 알림 글귀를 지금 앱 말로 보여 준다(5차).
//
// 알림은 만들어질 때의 제목·본문을 문서에 그대로 적어 둔다. 그래서 서버
// 글귀를 고쳐도 이미 쌓인 알림은 옛말 그대로 남는다. 저장된 값은 건드리지
// 않고, 보여줄 때만 지금 말로 바꾼다.

/// 예전 서버 문구의 게시판 이름을 지금 이름으로 바꾼다.
///
/// 서버 함수는 99813053에서 '일반' → '게시판'으로 고쳤지만, 그 전에 만들어져
/// 저장된 알림은 "일반에 새 댓글이 달렸어요"를 그대로 들고 있다. 탭과 칩은
/// '게시판'이라 같은 알림 안에서 이름이 달라 보였다. 게시판 글 알림에서만,
/// 서버가 쓰던 꼴('일반에 ', '일반의 ')만 바꾼다(닉네임 등 다른 곳의 '일반'은
/// 그대로).
String _renameBoard(String text, String boardType) {
  if (boardType != 'board') return text;
  return text.replaceAll('일반에 ', '게시판에 ').replaceAll('일반의 ', '게시판의 ');
}

/// 예전 투표 알림 제목. 앱은 어디서나 '마감'이라 부른다(b8fc9cc9, 308bd0c0).
const String _oldVoteEndTitle = '투표가 종료되었어요.';
const String voteEndTitleNow = '투표가 마감됐어요.';

const String _voteEndBodySuffix = ' 결과를 확인해 보세요.';

/// 알림 제목.
String displayNotificationTitle(String title, String boardType) {
  if (boardType == 'vote' && title.trim() == _oldVoteEndTitle) {
    return voteEndTitleNow;
  }
  return _renameBoard(title, boardType);
}

/// 알림 본문.
///
/// 예전 투표 마감 알림은 글 제목을 그대로 이어 붙여서("ㅇㅁㄴ 결과를 확인해
/// 보세요.") 어디까지가 제목인지 알 수 없었다. 지금 서버처럼 따옴표로 묶어
/// 보여 준다. 이미 묶여 있거나 제목이 없는 알림은 그대로 둔다.
String displayNotificationBody(String body, String boardType) {
  if (boardType == 'vote') {
    final trimmed = body.trim();
    if (trimmed.endsWith(_voteEndBodySuffix)) {
      final head =
          trimmed.substring(0, trimmed.length - _voteEndBodySuffix.length);
      if (head.isNotEmpty && !(head.startsWith("'") && head.endsWith("'"))) {
        return "'$head'$_voteEndBodySuffix";
      }
    }
  }
  return _renameBoard(body, boardType);
}

/// 알림 설정에서 투표 마감 알림을 부르는 말(5차 479).
///
/// 앱은 투표가 끝난 것을 어디서나 '마감'이라 부르는데(거르개, 카드의
/// 'N일 뒤 마감', 알림 제목) 설정 줄만 '종료'로 남아 있었다. 알림 제목과
/// 같은 파일에 둬서 다음에 또 갈리지 않게 한다.
const String voteEndPrefTitle = '참여한 투표 마감';
const String voteEndPrefSubtitle = '내가 참여한 투표가 마감돼 결과가 나오면';
