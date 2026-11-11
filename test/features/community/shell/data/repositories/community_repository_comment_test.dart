import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late CommunityRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = CommunityRepository(firestore: firestore);
  });

  Comment buildComment() => Comment(
        id: '',
        postId: 'post_1',
        authorId: 'user_1',
        authorNickname: '춘배',
        content: '좋은 글이네요',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  Future<void> seedPost() async {
    await firestore.collection('posts').doc('post_1').set({
      'title': '안녕하세요',
      'commentCount': 0,
    });
  }

  group('addComment', () {
    test('댓글을 쓰고 commentCount를 함께 올린다', () async {
      await seedPost();

      final created = await repository.addComment('post_1', buildComment());

      expect(created.id, isNotEmpty);
      final post = await firestore.collection('posts').doc('post_1').get();
      expect(post.data()!['commentCount'], 1);

      final comments = await firestore
          .collection('posts')
          .doc('post_1')
          .collection('comments')
          .get();
      expect(comments.docs, hasLength(1));
      expect(comments.docs.single.data()['content'], '좋은 글이네요');
    });

    test('글이 없으면 던진다', () async {
      await expectLater(
        repository.addComment('post_1', buildComment()),
        throwsA(isA<Exception>()),
      );

      // 여기서 "댓글도 안 남는다"까지 확인하고 싶지만 못 한다.
      // fake_cloud_firestore의 WriteBatch는 원자적이지 않아서, commit이
      // 던져도 앞선 set은 이미 반영돼 있다. 진짜 Firestore에서는 배치
      // 전체가 실패하고 아무것도 안 남는다. 그 보장은 여기서 확인되지 않는다.
    });
  });

  group('getComments', () {
    test('쓴 순서대로 돌려주고 문서 id를 채운다', () async {
      await seedPost();
      final first = await repository.addComment(
          'post_1', buildComment().copyWith(content: '첫 댓글'));
      final second = await repository.addComment(
          'post_1', buildComment().copyWith(content: '둘째 댓글'));

      final comments = await repository.getComments('post_1');

      expect(comments.map((c) => c.content), ['첫 댓글', '둘째 댓글']);
      expect(comments.map((c) => c.id), [first.id, second.id]);
    });
  });

  group('deleteComment', () {
    test('지우지 않고 삭제된 댓글로 표시한다', () async {
      await seedPost();
      final created = await repository.addComment('post_1', buildComment());

      await repository.deleteComment('post_1', created.id);

      final doc = await firestore
          .collection('posts')
          .doc('post_1')
          .collection('comments')
          .doc(created.id)
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['status'], 'deleted');
      expect(doc.data()!['content'], '이 댓글은 삭제된 댓글입니다.');
    });
  });
}
