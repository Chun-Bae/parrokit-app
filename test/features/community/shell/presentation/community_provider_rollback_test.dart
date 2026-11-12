// 낙관적 업데이트 되돌리기 다섯 곳의 회귀 테스트.
//
// 추천·스크랩·댓글 좋아요는 서버 호출 전에 화면의 수를 먼저 바꾸고, 실패하면
// 되돌린다. 전에는 await 전에 잡아 둔 인덱스로 되돌려서, 그 사이 목록이
// 바뀌면(차단으로 걸러지거나 새로 불러오면) 엉뚱한 글·댓글의 수가 1 깎였다.
//
// 글 수정·삭제는 orElse 없는 firstWhere를 써서, 목록에 없는 글이면
// "Bad state: No element"가 그대로 토스트에 떴다.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

/// 서버 호출을 손으로 끝낼 수 있는 저장소. 목록 읽기는 미리 넣어 둔 값을 준다.
class _ControlledRepository extends CommunityRepository {
  _ControlledRepository() : super(firestore: FakeFirebaseFirestore());

  List<Post> posts = [];
  List<Comment> comments = [];
  final Completer<void> pendingWrite = Completer<void>();
  final List<String> deletedPostIds = [];

  @override
  Future<PostPage> getPosts({
    String postType = 'board',
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async =>
      PostPage(posts: posts, lastDocument: null, hasMore: false);

  @override
  Future<List<Comment>> getComments(String postId) async => comments;

  @override
  Future<Set<String>> getLikedCommentIds(String userId) async => {};

  @override
  Future<void> toggleLike(String postId, String userId, bool isLiked) =>
      pendingWrite.future;

  @override
  Future<void> toggleScrap(String postId, String userId, bool isScrapped) =>
      pendingWrite.future;

  @override
  Future<void> toggleCommentLike(
    String postId,
    String commentId,
    String userId,
    bool isLiked,
  ) =>
      pendingWrite.future;

  @override
  Future<void> deletePost(String postId) async => deletedPostIds.add(postId);
}

Post _post(String id, String authorId, {int likes = 0, int scraps = 0}) => Post(
      id: id,
      postType: 'board',
      category: '자유',
      title: id,
      content: id,
      authorId: authorId,
      authorNickname: authorId,
      snippet: id,
      likeCount: likes,
      scrapCount: scraps,
    );

Comment _comment(String id, String authorId, {int likes = 0}) => Comment(
      id: id,
      authorId: authorId,
      authorNickname: authorId,
      content: id,
      postId: 'p',
      likeCount: likes,
    );

void main() {
  late _ControlledRepository repository;
  late CommunityProvider provider;

  setUp(() {
    repository = _ControlledRepository();
    provider = CommunityProvider(
      repository: repository,
      userService: FirebaseUserService(firestore: FakeFirebaseFirestore()),
    );
  });

  int likesOf(String id) => provider.posts.firstWhere((p) => p.id == id).likeCount;
  int scrapsOf(String id) => provider.posts.firstWhere((p) => p.id == id).scrapCount;
  int commentLikesOf(String id) =>
      provider.currentPostComments.firstWhere((c) => c.id == id).likeCount;

  test('추천이 실패하는 사이 목록이 바뀌어도 다른 글의 추천 수는 그대로다', () async {
    repository.posts = [
      _post('a', 'blocked', likes: 5),
      _post('b', 'me', likes: 10),
      _post('c', 'other', likes: 20),
    ];
    await provider.fetchPosts(refresh: true);

    final toggling = provider.toggleLike('b', 'me');
    expect(likesOf('b'), 11);

    // 서버 응답을 기다리는 사이 a의 작성자를 차단했다. b는 0번, c는 1번으로 당겨진다.
    provider.setBlockedUserIds(['blocked']);
    repository.pendingWrite.completeError(Exception('offline'));
    await toggling;

    expect(likesOf('b'), 10);
    expect(likesOf('c'), 20);
    expect(provider.isPostLiked('b'), isFalse);
  });

  test('스크랩이 실패하는 사이 목록이 바뀌어도 다른 글의 스크랩 수는 그대로다', () async {
    repository.posts = [
      _post('a', 'blocked', scraps: 5),
      _post('b', 'me', scraps: 10),
      _post('c', 'other', scraps: 20),
    ];
    await provider.fetchPosts(refresh: true);

    final toggling = provider.toggleScrap('b', 'me');
    expect(scrapsOf('b'), 11);

    provider.setBlockedUserIds(['blocked']);
    repository.pendingWrite.completeError(Exception('offline'));
    await toggling;

    expect(scrapsOf('b'), 10);
    expect(scrapsOf('c'), 20);
    expect(provider.isPostScrapped('b'), isFalse);
  });

  test('댓글 좋아요가 실패하는 사이 목록이 바뀌어도 다른 댓글의 좋아요 수는 그대로다', () async {
    repository.comments = [
      _comment('x', 'blocked', likes: 1),
      _comment('y', 'me', likes: 2),
      _comment('z', 'other', likes: 3),
    ];
    await provider.fetchComments('p', currentUserId: 'me');

    final toggling = provider.toggleCommentLike('p', 'y', 'me');
    expect(commentLikesOf('y'), 3);

    provider.setBlockedUserIds(['blocked']);
    repository.pendingWrite.completeError(Exception('offline'));
    await toggling;

    expect(commentLikesOf('y'), 2);
    expect(commentLikesOf('z'), 3);
    expect(provider.likedCommentIds, isNot(contains('y')));
  });

  test('목록에 없는 글을 수정하면 Bad state 대신 안내 문구가 나온다', () async {
    repository.posts = [_post('a', 'me')];
    await provider.fetchPosts(refresh: true);

    final ok = await provider.editPost(
      'missing',
      title: 't',
      content: 'c',
      category: '자유',
      tags: const [],
      existingImageUrls: const [],
      newImageFiles: const [],
      authorId: 'me',
    );

    expect(ok, isFalse);
    expect(provider.errorMessage, isNot(contains('Bad state')));
    expect(provider.errorMessage, contains('찾지 못했어요'));
    expect(provider.isLoading, isFalse);
  });

  test('목록에 없는 글을 지우면 Bad state 대신 안내 문구가 나오고 아무것도 지우지 않는다', () async {
    repository.posts = [_post('a', 'me')];
    await provider.fetchPosts(refresh: true);

    final ok = await provider.deletePost('missing');

    expect(ok, isFalse);
    expect(provider.errorMessage, isNot(contains('Bad state')));
    expect(provider.errorMessage, contains('찾지 못했어요'));
    expect(repository.deletedPostIds, isEmpty);
    expect(provider.posts.map((p) => p.id), ['a']);
  });
}
