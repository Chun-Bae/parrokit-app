// 글을 열었다가 바로 다른 글을 열었을 때 댓글 목록 회귀 테스트.
//
// 예전엔 늦게 끝난 앞 글의 댓글이 지금 글 목록에 덧붙었고, 같은 글을 두 번
// 부르면 댓글이 두 벌이 됐다.
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

/// 글별 댓글 읽기를 테스트가 끝내는 저장소. 같은 글을 여러 번 부르면 차례로 쌓인다.
class _CommentRepository extends CommunityRepository {
  _CommentRepository() : super(firestore: FakeFirebaseFirestore());

  final pending = <String, List<Completer<List<Comment>>>>{};

  void finish(String postId, {int call = 0}) =>
      pending[postId]![call].complete([_comment('$postId-c', postId)]);

  @override
  Future<List<Comment>> getComments(String postId) {
    final c = Completer<List<Comment>>();
    pending.putIfAbsent(postId, () => []).add(c);
    return c.future;
  }

  @override
  Future<Set<String>> getLikedCommentIds(String userId) async => {};
}

Comment _comment(String id, String postId) => Comment(
      id: id,
      authorId: '',
      authorNickname: '',
      content: id,
      postId: postId,
    );

void main() {
  late _CommentRepository repo;
  late CommunityProvider provider;

  setUp(() {
    repo = _CommentRepository();
    provider = CommunityProvider(
      repository: repo,
      userService: FirebaseUserService(firestore: FakeFirebaseFirestore()),
    );
  });

  List<String> ids() => provider.currentPostComments.map((c) => c.id).toList();

  test('앞 글 댓글이 늦게 와도 지금 글 목록에 섞이지 않는다', () async {
    final a = provider.fetchComments('a');
    final b = provider.fetchComments('b');

    repo.finish('b');
    await b;
    repo.finish('a');
    await a;

    expect(ids(), ['b-c']);
  });

  test('지금 글 댓글이 먼저 와도 앞 글 댓글은 버린다', () async {
    final a = provider.fetchComments('a');
    final b = provider.fetchComments('b');

    repo.finish('a');
    await a;
    expect(ids(), isEmpty);

    repo.finish('b');
    await b;
    expect(ids(), ['b-c']);
  });

  test('같은 글을 두 번 불러도 댓글은 한 벌이다', () async {
    final first = provider.fetchComments('a');
    final second = provider.fetchComments('a');

    repo.finish('a', call: 0);
    repo.finish('a', call: 1);
    await first;
    await second;

    expect(ids(), ['a-c']);
  });
}
