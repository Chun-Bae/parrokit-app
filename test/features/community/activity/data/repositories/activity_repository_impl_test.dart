import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/activity/data/repositories/activity_repository_impl.dart';

void main() {
  group('ActivityRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late ActivityRepositoryImpl repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = ActivityRepositoryImpl(firestore: firestore);
    });

    test('vote/written은 작성글이 아닌 참여한 투표를 조회한다', () async {
      await _seedPost(firestore, postId: 'vote_1', postType: 'vote');
      await _seedPost(firestore, postId: 'vote_2', postType: 'vote');

      await firestore
          .collection('users')
          .doc('u1')
          .collection('voted_posts')
          .doc('vote_1')
          .set({'selectedOption': 0, 'votedAt': DateTime(2026, 6, 1)});

      final page = await repository.getActivities(
        userId: 'u1',
        boardType: 'vote',
        activityType: 'written',
      );

      expect(page.items.length, 1);
      expect(page.items.first.id, 'vote_1');
      expect(page.items.first.sourcePostId, 'vote_1');
      expect(page.items.first.boardType, 'vote');
    });

    test('vote/written은 votedAt 내림차순으로 정렬된다', () async {
      await _seedPost(firestore, postId: 'vote_old', postType: 'vote');
      await _seedPost(firestore, postId: 'vote_new', postType: 'vote');

      await firestore
          .collection('users')
          .doc('u1')
          .collection('voted_posts')
          .doc('vote_old')
          .set({'selectedOption': 0, 'votedAt': DateTime(2026, 5, 1)});
      await firestore
          .collection('users')
          .doc('u1')
          .collection('voted_posts')
          .doc('vote_new')
          .set({'selectedOption': 0, 'votedAt': DateTime(2026, 6, 1)});

      final page = await repository.getActivities(
        userId: 'u1',
        boardType: 'vote',
        activityType: 'written',
      );

      expect(page.items.length, 2);
      expect(page.items[0].id, 'vote_new');
      expect(page.items[1].id, 'vote_old');
    });

    test('question/commented는 답변(parentId=null)만 조회한다', () async {
      await _seedPost(firestore, postId: 'q1', postType: 'question');

      await _seedComment(
        firestore,
        postId: 'q1',
        commentId: 'answer_1',
        authorId: 'u1',
        postType: 'question',
        parentId: null,
      );
      await _seedComment(
        firestore,
        postId: 'q1',
        commentId: 'reply_1',
        authorId: 'u1',
        postType: 'question',
        parentId: 'answer_1',
      );

      final page = await repository.getActivities(
        userId: 'u1',
        boardType: 'question',
        activityType: 'commented',
      );

      expect(page.items.length, 1);
      expect(page.items.first.id, 'answer_1');
      expect(page.items.first.sourcePostId, 'q1');
    });

    test('question/commented_reply는 답변의 댓글(parentId!=null)만 조회한다', () async {
      await _seedPost(firestore, postId: 'q1', postType: 'question');

      await _seedComment(
        firestore,
        postId: 'q1',
        commentId: 'answer_1',
        authorId: 'u1',
        postType: 'question',
        parentId: null,
      );
      await _seedComment(
        firestore,
        postId: 'q1',
        commentId: 'reply_1',
        authorId: 'u1',
        postType: 'question',
        parentId: 'answer_1',
      );

      final page = await repository.getActivities(
        userId: 'u1',
        boardType: 'question',
        activityType: 'commented_reply',
      );

      expect(page.items.length, 1);
      expect(page.items.first.id, 'reply_1');
      expect(page.items.first.sourcePostId, 'q1');
    });

    test('liked_comment는 boardType으로 필터되고 sourcePostId를 유지한다', () async {
      await _seedPost(firestore, postId: 'b1', postType: 'board');
      await _seedPost(firestore, postId: 'q1', postType: 'question');

      await _seedComment(
        firestore,
        postId: 'b1',
        commentId: 'c_board',
        authorId: 'u2',
        postType: 'board',
      );
      await _seedComment(
        firestore,
        postId: 'q1',
        commentId: 'c_question',
        authorId: 'u3',
        postType: 'question',
      );

      await firestore
          .collection('users')
          .doc('u1')
          .collection('comment_likes')
          .doc('b1_c_board')
          .set({
        'postId': 'b1',
        'commentId': 'c_board',
        'createdAt': DateTime(2026, 6, 1),
      });
      await firestore
          .collection('users')
          .doc('u1')
          .collection('comment_likes')
          .doc('q1_c_question')
          .set({
        'postId': 'q1',
        'commentId': 'c_question',
        'createdAt': DateTime(2026, 6, 1),
      });

      final page = await repository.getActivities(
        userId: 'u1',
        boardType: 'board',
        activityType: 'liked_comment',
      );

      expect(page.items.length, 1);
      expect(page.items.first.id, 'c_board');
      expect(page.items.first.sourcePostId, 'b1');
      expect(page.items.first.boardType, 'board');
    });

    test('liked_comment는 동일 commentId가 있어도 postId로 정확히 조회한다', () async {
      await _seedPost(firestore, postId: 'b1', postType: 'board');
      await _seedPost(firestore, postId: 'b2', postType: 'board');

      await _seedComment(
        firestore,
        postId: 'b1',
        commentId: 'c_same',
        authorId: 'u2',
        postType: 'board',
      );
      await _seedComment(
        firestore,
        postId: 'b2',
        commentId: 'c_same',
        authorId: 'u3',
        postType: 'board',
      );

      await firestore
          .collection('users')
          .doc('u1')
          .collection('comment_likes')
          .doc('b1_c_same')
          .set({
        'postId': 'b1',
        'commentId': 'c_same',
        'createdAt': DateTime(2026, 6, 1),
      });

      final page = await repository.getActivities(
        userId: 'u1',
        boardType: 'board',
        activityType: 'liked_comment',
      );

      expect(page.items.length, 1);
      expect(page.items.first.id, 'c_same');
      expect(page.items.first.sourcePostId, 'b1');
    });

    test('board/written은 cursor로 다음 페이지를 이어서 조회한다', () async {
      await _seedPost(
        firestore,
        postId: 'board_old',
        postType: 'board',
        authorId: 'u1',
        createdAt: DateTime(2026, 6, 1, 10),
      );
      await _seedPost(
        firestore,
        postId: 'board_new',
        postType: 'board',
        authorId: 'u1',
        createdAt: DateTime(2026, 6, 2, 10),
      );

      final firstPage = await repository.getActivities(
        userId: 'u1',
        boardType: 'board',
        activityType: 'written',
        limit: 1,
      );

      expect(firstPage.items.length, 1);
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.nextCursor, isNotNull);
      expect(firstPage.items.first.id, 'board_new');

      final secondPage = await repository.getActivities(
        userId: 'u1',
        boardType: 'board',
        activityType: 'written',
        limit: 1,
        startAfter: firstPage.nextCursor,
      );

      expect(secondPage.items.length, 1);
      expect(secondPage.hasMore, isFalse);
      expect(secondPage.items.first.id, 'board_old');
    });
  });
}

Future<void> _seedPost(
  FakeFirebaseFirestore firestore, {
  required String postId,
  required String postType,
  String? authorId,
  DateTime? createdAt,
}) async {
  await firestore.collection('posts').doc(postId).set({
    'postType': postType,
    'category': 'free',
    'title': '$postType-title',
    'content': '$postType-content',
    'authorId': authorId ?? 'author_$postId',
    'authorNickname': 'author',
    'snippet': 'snippet',
    'createdAt': createdAt ?? DateTime(2026, 6, 1),
    'updatedAt': createdAt ?? DateTime(2026, 6, 1),
    'likeCount': 0,
    'commentCount': 0,
    'viewCount': 0,
  });
}

Future<void> _seedComment(
  FakeFirebaseFirestore firestore, {
  required String postId,
  required String commentId,
  required String authorId,
  required String postType,
  String? parentId,
}) async {
  await firestore
      .collection('posts')
      .doc(postId)
      .collection('comments')
      .doc(commentId)
      .set({
    'authorId': authorId,
    'authorNickname': 'writer',
    'content': 'comment-$commentId',
    'postType': postType,
    'parentId': parentId,
    'createdAt': DateTime(2026, 6, 1),
    'updatedAt': DateTime(2026, 6, 1),
    'likeCount': 0,
  });
}
