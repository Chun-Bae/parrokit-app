// 내 활동 화면이 비었을 때 아래에 적는 한 줄.
//
// 전에는 게시판·질문·투표가 모두 같은 말을 썼다. 답변 목록에도 '글에 남긴
// 말이 여기에 모여요'라고 적혀 있었고, 댓글 좋아요 목록은 '글'이라고 했다.
// 220에서 정한 대로 질문에 바로 다는 것은 '답변', 답변에 다는 것은
// '답글'이다(5차).

String activityEmptyDescription(String boardType, String activityType) {
  switch (activityType) {
    case 'written':
    case 'written_posted':
      if (boardType == 'vote') {
        // 투표는 '쓰는' 것이 아니라 만들거나 참여하는 것이다(5차).
        return activityType == 'written'
            ? '마음에 드는 투표에 참여해 보세요.'
            : '첫 투표를 만들면 여기에 모여요.';
      }
      return boardType == 'question'
          ? '첫 질문을 올리면 여기에 모여요.'
          : '첫 글을 남기면 여기에 모여요.';
    case 'commented':
      switch (boardType) {
        case 'question':
          return '질문에 남긴 답변이 여기에 모여요.';
        case 'vote':
          return '투표에 남긴 댓글이 여기에 모여요.';
        default:
          return '글에 남긴 댓글이 여기에 모여요.';
      }
    case 'commented_reply':
      return boardType == 'question'
          ? '답변에 남긴 답글이 여기에 모여요.'
          : '댓글에 남긴 답글이 여기에 모여요.';
    case 'liked':
      return boardType == 'question' ? '공감한 질문이 여기에 모여요.' : '공감한 글이 여기에 모여요.';
    case 'liked_comment':
      return boardType == 'question'
          ? '좋아요한 답변과 답글이 여기에 모여요.'
          : '좋아요한 댓글이 여기에 모여요.';
    case 'scraped':
      // 다른 갈래는 모두 묶음에 따라 '글·질문·투표'로 갈리는데 여기만
      // 늘 '글'이었다. 제목은 '질문 - 스크랩'인데 아래는 '다시 볼 글을
      // 스크랩해 두세요'라 무엇을 담는 곳인지 어긋났다(5차 480).
      return switch (boardType) {
        'question' => '나중에 다시 볼 질문을 스크랩해 두세요.',
        'vote' => '나중에 다시 볼 투표를 스크랩해 두세요.',
        _ => '나중에 다시 볼 글을 스크랩해 두세요.',
      };
    default:
      return '커뮤니티에서 한 일이 여기에 모여요.';
  }
}

/// 목록 맨 위에 적는 '총 ○○ N개'(5차 407).
///
/// 전에는 '좋아요한 댓글'에도 '총 공감 N개'라고 적었다. 글·질문은 엄지
/// '공감', 댓글·답변은 하트 '좋아요'로 나눠 부르기로 했는데(89d57b67)
/// 이 줄만 옛 이름이었다.
String activityCountLabel(String boardType, String activityType, int count) {
  final typeLabel = switch (activityType) {
    'written' || 'written_posted' => switch (boardType) {
        'vote' => '투표',
        'question' => '질문',
        _ => '글',
      },
    'commented' => boardType == 'question' ? '답변' : '댓글',
    'commented_reply' => '답글',
    'liked' => '공감',
    'liked_comment' => '좋아요',
    'scraped' => '스크랩',
    _ => '활동',
  };
  return '총 $typeLabel $count개';
}
