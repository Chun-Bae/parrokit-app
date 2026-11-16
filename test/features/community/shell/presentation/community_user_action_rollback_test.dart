// 공감·스크랩을 눌렀는데 서버 쓰기가 실패하면 수와 표시가 되돌아간다(5차).
//
// 화면은 누르자마자 수를 올리고(낙관적 표시) 나중에 서버에 쓴다. 실패했을 때
// 되돌리지 않으면, 서버에는 없는 공감이 화면에만 남는다. 되돌릴 글을 다시
// 찾는 것도 중요하다 — 기다리는 사이 목록이 통째로 바뀌면 예전 자리(index)를
// 그대로 쓰다가 엉뚱한 글의 수를 건드린다.
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

Post _post(String id, {int likeCount = 0, int scrapCount = 0}) => Post(
      id: id,
      postType: 'board',
      category: '자유',
      title: '글 $id',
      content: '내용',
      authorId: 'someone',
      authorNickname: '누군가',
      snippet: '내용',
      likeCount: likeCount,
      scrapCount: scrapCount,
      createdAt: DateTime(2026, 11, 1),
    );

class _Repo extends CommunityRepository {
  _Repo(this.posts) : super(firestore: FakeFirebaseFirestore());

  List<Post> posts;
  bool fail = false;

  /// 쓰기를 붙잡아 둘 때 쓴다. 테스트가 끝내 주면 그때 성공·실패한다.
  Completer<void>? hold;

  @override
  Future<PostPage> getPosts({
    String postType = 'board',
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async =>
      PostPage(posts: posts, lastDocument: null, hasMore: false);

  @override
  Future<Map<String, bool>> getUserPostActions(
          String postId, String userId) async =>
      {'isLiked': false, 'isScrapped': false};

  @override
  Future<void> toggleLike(String postId, String userId, bool isLiked) async {
    if (hold != null) await hold!.future;
    if (fail) throw Exception('서버 오류');
  }

  @override
  Future<void> toggleScrap(
      String postId, String userId, bool isScrapped) async {
    if (fail) throw Exception('서버 오류');
  }
}

void main() {
  late _Repo repo;
  late CommunityProvider provider;

  setUp(() {
    repo = _Repo([_post('a', likeCount: 3), _post('b', likeCount: 10)]);
    provider = CommunityProvider(
      repository: repo,
      userService: FirebaseUserService(firestore: FakeFirebaseFirestore()),
    );
  });

  test('공감이 되면 수가 하나 오르고 표시가 켜진다', () async {
    await provider.fetchPosts(postType: 'board', refresh: true);
    await provider.toggleLike('a', 'me');

    expect(provider.isPostLiked('a'), isTrue);
    expect(provider.posts.firstWhere((p) => p.id == 'a').likeCount, 4);
    expect(provider.errorMessage, isNull);
  });

  test('공감 쓰기가 실패하면 수와 표시가 되돌아간다', () async {
    await provider.fetchPosts(postType: 'board', refresh: true);
    repo.fail = true;
    await provider.toggleLike('a', 'me');

    expect(provider.isPostLiked('a'), isFalse);
    expect(provider.posts.firstWhere((p) => p.id == 'a').likeCount, 3);
    // 안내는 앱이 쓰는 말('공감')과 말투로(5차, 예전 '추천 처리에 실패했습니다.').
    expect(provider.errorMessage, '공감하지 못했어요. 잠시 후 다시 해 주세요.');
  });

  test('기다리는 사이 목록이 바뀌어도 되돌릴 글을 다시 찾는다', () async {
    await provider.fetchPosts(postType: 'board', refresh: true);
    repo.fail = true;

    // 쓰기가 끝나기 전에 목록이 통째로 바뀐다(순서도 뒤집힌다).
    // 화면에는 이미 공감이 더해져 있으므로 a는 4로 온다.
    repo.hold = Completer<void>();
    final pending = provider.toggleLike('a', 'me');
    repo.posts = [_post('b', likeCount: 10), _post('a', likeCount: 4)];
    await provider.fetchPosts(postType: 'board', refresh: true);
    repo.hold!.complete();
    await pending;

    // 'a'만 되돌아가고 'b'는 그대로다.
    expect(provider.posts.firstWhere((p) => p.id == 'a').likeCount, 3);
    expect(provider.posts.firstWhere((p) => p.id == 'b').likeCount, 10);
  });

  test('스크랩도 실패하면 되돌아간다', () async {
    repo.posts = [_post('a', scrapCount: 2)];
    await provider.fetchPosts(postType: 'board', refresh: true);
    repo.fail = true;
    await provider.toggleScrap('a', 'me');

    expect(provider.isPostScrapped('a'), isFalse);
    expect(provider.posts.firstWhere((p) => p.id == 'a').scrapCount, 2);
  });

  test('로그인하지 않았으면 아무것도 하지 않는다', () async {
    await provider.fetchPosts(postType: 'board', refresh: true);
    await provider.toggleLike('a', '');

    expect(provider.isPostLiked('a'), isFalse);
    expect(provider.posts.firstWhere((p) => p.id == 'a').likeCount, 3);
  });

  test('되돌리기만 하지 않고 까닭을 띄운다(5차 382)', () {
    // 화면마다 따로 알리면 빠지는 곳이 생긴다. provider가 한 번 알린다.
    final code = File(
            'lib/features/community/shell/presentation/providers/community_provider_user_action.dart')
        .readAsStringSync();
    expect('showToast(_errorMessage!);'.allMatches(code).length, 2);
  });
}
