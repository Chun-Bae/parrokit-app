// 한 탭 목록을 읽는 중에 다른 탭으로 바꿨을 때의 회귀 테스트.
//
// 예전엔 fetchPosts가 읽는 중이면 새 요청을 그냥 버려서, 질문을 읽는 사이
// 게시판으로 넘어가면 게시판 탭에 질문 글만 남아 '등록된 게시글이 없습니다'가 떴다.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

/// 종류별 목록 읽기를 테스트가 끝내는 저장소.
class _TypedRepository extends CommunityRepository {
  _TypedRepository() : super(firestore: FakeFirebaseFirestore());

  final pending = <String, Completer<PostPage>>{};
  final requested = <String>[];

  void finish(String type) => pending[type]!.complete(PostPage(
        posts: [_post('$type-1', type)],
        lastDocument: null,
        hasMore: false,
      ));

  @override
  Future<PostPage> getPosts({
    String postType = 'board',
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) {
    requested.add(postType);
    return (pending[postType] = Completer<PostPage>()).future;
  }
}

Post _post(String id, String type) => Post(
      id: id,
      postType: type,
      category: '자유',
      title: id,
      content: id,
      authorId: '',
      authorNickname: '',
      snippet: id,
    );

Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds: 80));

void main() {
  late _TypedRepository repo;
  late CommunityProvider provider;

  setUp(() {
    repo = _TypedRepository();
    provider = CommunityProvider(
      repository: repo,
      userService: FirebaseUserService(firestore: FakeFirebaseFirestore()),
    );
  });

  test('질문을 읽는 사이 게시판으로 바꾸면 끝난 뒤 게시판을 읽는다', () async {
    final question = provider.fetchPosts(postType: 'question', refresh: true);
    final board = provider.fetchPosts(postType: 'board', refresh: true);

    repo.finish('question');
    await question;
    await _wait();
    expect(repo.requested, ['question', 'board']);

    repo.finish('board');
    await board;
    expect(provider.posts.map((p) => p.id), ['board-1']);
    expect(provider.getBoardPostsByFilter('전체'), hasLength(1));
  });

  test('기다리는 사이 또 바꾸면 마지막 탭만 읽는다', () async {
    final question = provider.fetchPosts(postType: 'question', refresh: true);
    final board = provider.fetchPosts(postType: 'board', refresh: true);
    final vote = provider.fetchPosts(postType: 'vote', refresh: true);

    repo.finish('question');
    await question;
    await board;
    await _wait();
    expect(repo.requested, ['question', 'vote']);

    repo.finish('vote');
    await vote;
    expect(provider.posts.map((p) => p.id), ['vote-1']);
  });

  test('읽던 탭으로 돌아오면 기다리던 다른 탭 요청은 그만둔다', () async {
    final question = provider.fetchPosts(postType: 'question', refresh: true);
    final board = provider.fetchPosts(postType: 'board', refresh: true);
    await provider.fetchPosts(postType: 'question', refresh: true);

    repo.finish('question');
    await question;
    await board;
    await _wait();
    expect(repo.requested, ['question']);
    expect(provider.posts.map((p) => p.id), ['question-1']);
  });

  test('같은 탭을 읽는 중에 또 부르면 한 번만 읽는다', () async {
    final first = provider.fetchPosts(postType: 'board', refresh: true);
    await provider.fetchPosts(postType: 'board', refresh: true);
    repo.finish('board');
    await first;
    expect(repo.requested, ['board']);
  });
}
