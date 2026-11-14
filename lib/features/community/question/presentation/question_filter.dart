import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';

/// 질문 탭의 거르기(status)와 정렬(sort)을 함께 적용한다.
///
/// 전에는 둘이 한 줄에 섞여 있어 하나만 고를 수 있었다. '답변 대기'를
/// 보면서 '공감 순'으로 볼 수 없었다(5차).
///
/// 서버 조회 순서는 그대로 두고, 이미 불러온 질문 안에서만 다시 정렬한다.
/// 서버 정렬에는 Firestore 인덱스 배포가 필요해서다(5차 결정).
List<Post> questionsFor(
  List<Post> posts, {
  required String status,
  required String sort,
}) {
  var questions = posts.where((p) => p.postType == 'question').toList();

  // 이름이 아니라 목록의 순서로 고른다(이름이 바뀌어도 그대로).
  switch (CommunityFilters.questionStatus.indexOf(status)) {
    case 1: // 답변 대기
      questions =
          questions.where((p) => p.questionStatus == 'waiting').toList();
    case 2: // 채택 완료
      questions =
          questions.where((p) => p.questionStatus == 'resolved').toList();
    default: // 전체
      break;
  }

  switch (CommunityFilters.questionSort.indexOf(sort)) {
    case 1: // 공감 순: 공감 많은 순, 같으면 댓글 많은 순, 그다음 최신 순
      questions.sort((a, b) {
        final byLike = b.likeCount.compareTo(a.likeCount);
        if (byLike != 0) return byLike;
        final byComment = b.commentCount.compareTo(a.commentCount);
        if (byComment != 0) return byComment;
        return _newestFirst(a, b);
      });
    case 2: // 오래된 순: 작성 시각이 없는 글은 맨 뒤로
      questions.sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });
    default: // 최신 순
      questions.sort(_newestFirst);
  }
  return questions;
}

int _newestFirst(Post a, Post b) {
  final at = a.createdAt, bt = b.createdAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}

/// 답변을 기다리는 질문의 마감 안내. 질문 쓰기에서 고른 마감 기한(expireAt)을 어디에도
/// 보여 주지 않았다(5차). 기한이 지나도 서버는 채택을 막지 않으므로 '마감'이 아니라
/// '기한 지남'이라고만 말한다. 기한이 없으면 null.
String? questionDeadlineLabel(DateTime? expireAt, DateTime now) {
  if (expireAt == null) return null;
  final left = expireAt.difference(now);
  if (left.isNegative) return '기한 지남';
  if (left.inDays >= 1) return '${left.inDays}일 남음';
  if (left.inHours >= 1) return '${left.inHours}시간 남음';
  return '곧 마감';
}
