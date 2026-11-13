import 'package:parrokit/data/models/post.dart';

/// 질문 탭 필터(CommunityFilters.question)에 맞춰 질문을 거르고 정렬한다.
///
/// 서버 조회 순서(최신순)는 그대로 두고, 이미 불러온 질문 안에서만 다시
/// 정렬한다. 서버 정렬에는 Firestore 인덱스 배포가 필요해서다(5차 결정).
/// 예전에는 '화제의 질문'·'오래된 질문'이 아무것도 바꾸지 않아 '전체'와 같았다.
List<Post> questionsForFilter(List<Post> posts, String filter) {
  final questions = posts.where((p) => p.postType == 'question').toList();
  switch (filter) {
    case '채택 완료':
      return questions.where((p) => p.questionStatus == 'resolved').toList();
    case '답변 대기중':
      return questions.where((p) => p.questionStatus == 'waiting').toList();
    case '화제의 질문':
      // 공감 많은 순, 같으면 댓글 많은 순, 그다음 최신 순.
      return questions
        ..sort((a, b) {
          final byLike = b.likeCount.compareTo(a.likeCount);
          if (byLike != 0) return byLike;
          final byComment = b.commentCount.compareTo(a.commentCount);
          if (byComment != 0) return byComment;
          return _newestFirst(a, b);
        });
    case '오래된 질문':
      // 작성 시각이 없는 글은 맨 뒤로.
      return questions
        ..sort((a, b) {
          final at = a.createdAt, bt = b.createdAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return at.compareTo(bt);
        });
    default: // '전체'
      return questions;
  }
}

int _newestFirst(Post a, Post b) {
  final at = a.createdAt, bt = b.createdAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}
