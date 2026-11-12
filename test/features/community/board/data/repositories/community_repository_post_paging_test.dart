import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';

/// getPosts의 페이징.
///
/// 전에는 글 목록만 돌려줘서 다음 페이지를 읽을 커서가 없었다. 그래서
/// CommunityProvider의 _lastDocument는 선언만 되어 있고 끝까지 null이었고,
/// 게시판·질문·투표가 각각 최신 20개까지만 보였다.
///
/// 한 가지는 여기서 확인할 수 없다. fake_cloud_firestore 4.1.1은
/// startAfterDocument를 지원하지 않고 늘 빈 결과를 돌려준다(오름차순,
/// 내림차순 모두). 그래서 "커서를 넘기면 21번째 글부터 온다"는 실제 동작은
/// 에뮬레이터나 실제 Firestore로만 확인된다. 아래 테스트는 커서가 올바른
/// 문서를 가리키는지와 hasMore 판단까지만 본다.
void main() {
  late FakeFirebaseFirestore firestore;
  late CommunityRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = CommunityRepository(firestore: firestore);
  });

  Future<void> seedPosts(int count, {String postType = 'board'}) async {
    for (var i = 0; i < count; i++) {
      await firestore.collection('posts').doc('${postType}_$i').set({
        'postType': postType,
        'title': '글 $i',
        'content': '내용 $i',
        'authorId': 'user_1',
        // 최신순 정렬이므로 i가 클수록 먼저 온다.
        'createdAt':
            DateTime(2026, 1, 1).add(Duration(minutes: i)).toIso8601String(),
        'viewCount': 0,
        'likeCount': 0,
        'commentCount': 0,
        'scrapCount': 0,
        'status': 'normal',
        'reportCount': 0,
      });
    }
  }

  test('첫 페이지가 다음 페이지를 읽을 커서를 들고 온다', () async {
    await seedPosts(25);

    final first = await repository.getPosts(limit: 20);
    expect(first.posts, hasLength(20));
    expect(first.hasMore, isTrue);

    // 이것이 전에 없던 것이다. 커서가 없어서 21번째 글로 넘어갈 수 없었다.
    expect(first.lastDocument, isNotNull);
    // 커서는 이 페이지의 마지막 글을 가리켜야 한다. 다른 문서를 가리키면
    // 다음 페이지가 글을 빠뜨리거나 겹친다.
    expect(first.lastDocument!.id, first.posts.last.id);
  });

  test('커서를 안 넘기면 같은 페이지가 다시 온다', () async {
    await seedPosts(25);

    final first = await repository.getPosts(limit: 20);
    final again = await repository.getPosts(limit: 20);

    expect(
      again.posts.map((p) => p.id).toList(),
      first.posts.map((p) => p.id).toList(),
    );
  });

  test('글이 페이지보다 적으면 더 없다고 알린다', () async {
    await seedPosts(3);

    final page = await repository.getPosts(limit: 20);
    expect(page.posts, hasLength(3));
    expect(page.hasMore, isFalse);
  });

  test('글이 없으면 커서도 없다', () async {
    final page = await repository.getPosts(limit: 20);
    expect(page.posts, isEmpty);
    expect(page.hasMore, isFalse);
    expect(page.lastDocument, isNull);
  });

  test('다른 게시판 종류는 섞이지 않는다', () async {
    await seedPosts(5, postType: 'board');
    await seedPosts(5, postType: 'vote');

    final page = await repository.getPosts(postType: 'vote', limit: 20);
    expect(page.posts, hasLength(5));
    expect(page.posts.every((p) => p.postType == 'vote'), isTrue);
  });
}
