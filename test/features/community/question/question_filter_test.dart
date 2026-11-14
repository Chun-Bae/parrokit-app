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

  List<String> idsFor({String status = '전체', String sort = '최신 순'}) =>
      ids(questionsFor(posts, status: status, sort: sort));

  test('전체 + 최신 순이 기본이다', () {
    expect(idsFor(), [
      'new-popular',
      'mid-tie-less-comments',
      'mid-tie-more-comments',
      'old-many',
      'no-date',
    ]);
  });

  test('거르기는 상태만 보고 정렬은 건드리지 않는다', () {
    expect(idsFor(status: '채택 완료'), ['old-many']);
    expect(idsFor(status: '답변 대기'), isNot(contains('old-many')));
  });

  test('공감 순은 공감 많은 순, 같으면 댓글 많은 순', () {
    expect(idsFor(sort: '공감 순'), [
      'old-many',
      'new-popular',
      'mid-tie-more-comments',
      'mid-tie-less-comments',
      'no-date',
    ]);
  });

  test('오래된 순은 작성 순, 날짜 없는 글은 맨 뒤', () {
    expect(idsFor(sort: '오래된 순'), [
      'old-many',
      'mid-tie-more-comments',
      'mid-tie-less-comments',
      'new-popular',
      'no-date',
    ]);
  });

  test('거르기와 정렬을 함께 쓸 수 있다', () {
    // 전에는 한 줄 다섯 칸이라 '답변 대기'를 보면서 '공감 순'으로 볼 수
    // 없었다(5차).
    expect(idsFor(status: '답변 대기', sort: '공감 순'), [
      'new-popular',
      'mid-tie-more-comments',
      'mid-tie-less-comments',
      'no-date',
    ]);
  });

  test('원래 목록은 건드리지 않는다', () {
    final before = ids(posts);
    questionsFor(posts, status: '전체', sort: '공감 순');
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
