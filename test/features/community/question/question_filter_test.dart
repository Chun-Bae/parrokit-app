import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/question/presentation/question_filter.dart';

Post q(String id,
        {int likes = 0,
        int comments = 0,
        DateTime? at,
        String status = 'waiting',
        String type = 'question'}) =>
    Post(
      id: id,
      postType: type,
      category: '질문',
      title: id,
      content: '',
      authorId: 'a',
      authorNickname: 'a',
      snippet: '',
      likeCount: likes,
      commentCount: comments,
      createdAt: at,
      questionStatus: status,
    );

List<String> ids(List<Post> posts) => posts.map((p) => p.id).toList();

void main() {
  final day = DateTime(2026, 11, 1);
  final posts = [
    q('new-popular', likes: 7, at: day.add(const Duration(days: 3))),
    q('old-many', likes: 9, at: day, status: 'resolved'),
    q('mid-tie-more-comments', likes: 5, comments: 4, at: day.add(const Duration(days: 1))),
    q('mid-tie-less-comments', likes: 5, comments: 1, at: day.add(const Duration(days: 2))),
    q('no-date', likes: 0),
    q('board-post', likes: 99, at: day, type: 'board'),
  ];

  test('전체는 질문만 남기고 순서를 바꾸지 않는다', () {
    expect(ids(questionsForFilter(posts, '전체')), [
      'new-popular',
      'old-many',
      'mid-tie-more-comments',
      'mid-tie-less-comments',
      'no-date',
    ]);
  });

  test('채택 완료와 답변 대기는 상태로 거른다', () {
    expect(ids(questionsForFilter(posts, '채택 완료')), ['old-many']);
    expect(ids(questionsForFilter(posts, '답변 대기')), isNot(contains('old-many')));
  });

  test('공감 순은 공감 많은 순, 같으면 댓글 많은 순', () {
    expect(ids(questionsForFilter(posts, '공감 순')), [
      'old-many',
      'new-popular',
      'mid-tie-more-comments',
      'mid-tie-less-comments',
      'no-date',
    ]);
  });

  test('오래된 순은 작성 순, 날짜 없는 글은 맨 뒤', () {
    expect(ids(questionsForFilter(posts, '오래된 순')), [
      'old-many',
      'mid-tie-more-comments',
      'mid-tie-less-comments',
      'new-popular',
      'no-date',
    ]);
  });

  test('원래 목록은 건드리지 않는다', () {
    final before = ids(posts);
    questionsForFilter(posts, '공감 순');
    expect(ids(posts), before);
  });

  test('마감 안내는 남은 때를 말하고, 지나면 기한 지남', () {
    final now = DateTime(2026, 11, 14, 12);
    expect(questionDeadlineLabel(null, now), isNull);
    expect(questionDeadlineLabel(now.add(const Duration(days: 2, hours: 3)), now),
        '2일 남음');
    expect(questionDeadlineLabel(now.add(const Duration(hours: 5)), now),
        '5시간 남음');
    expect(questionDeadlineLabel(now.add(const Duration(minutes: 20)), now),
        '곧 마감');
    expect(questionDeadlineLabel(now.subtract(const Duration(minutes: 1)), now),
        '기한 지남');
  });
}
