// 글을 열었다가 바로 다른 글을 열었을 때 공감·스크랩 표시 회귀 테스트.
//
// 예전엔 늦게 끝난 앞 글의 공감 여부가 지금 글에 표시됐고, 그 상태로 공감을
// 누르면 반대 값을 서버에 보냈다.
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

class _ActionsRepository extends CommunityRepository {
  _ActionsRepository() : super(firestore: FakeFirebaseFirestore());

  final pending = <String, Completer<Map<String, bool>>>{};
  final likeWrites = <(String, bool)>[];

  void finish(String postId, {required bool liked, bool scrapped = false}) =>
      pending[postId]!.complete({'isLiked': liked, 'isScrapped': scrapped});

  @override
  Future<Map<String, bool>> getUserPostActions(
          String postId, String userId) =>
      (pending[postId] = Completer()).future;

  @override
  Future<void> toggleLike(String postId, String userId, bool isLiked) async =>
      likeWrites.add((postId, isLiked));
}

void main() {
  late _ActionsRepository repo;
  late CommunityProvider provider;

  setUp(() {
    repo = _ActionsRepository();
    provider = CommunityProvider(
      repository: repo,
      userService: FirebaseUserService(firestore: FakeFirebaseFirestore()),
    );
  });

  test('앞 글 공감 여부가 늦게 와도 지금 글 표시는 그대로다', () async {
    final a = provider.loadUserActions('a', userId: 'me');
    final b = provider.loadUserActions('b', userId: 'me');

    repo.finish('b', liked: false);
    await b;
    repo.finish('a', liked: true, scrapped: true);
    await a;

    expect(provider.isCurrentPostLiked, isFalse);
    expect(provider.isCurrentPostScrapped, isFalse);
    // 앞 글 값은 그 글 몫으로 남는다.
    expect(provider.isPostLiked('a'), isTrue);
    expect(provider.isPostScrapped('a'), isTrue);
  });

  test('지금 글 값이 오기 전에 앞 글 값이 와도 지금 글 공감은 바르게 보낸다',
      () async {
    final a = provider.loadUserActions('a', userId: 'me');
    final b = provider.loadUserActions('b', userId: 'me');

    repo.finish('a', liked: true);
    await a;
    expect(provider.isCurrentPostLiked, isFalse);

    // b의 값이 오기 전에 공감을 누른다. b는 아직 공감하지 않은 글이다.
    await provider.toggleLike('b', 'me');
    expect(repo.likeWrites, [('b', true)]);

    repo.finish('b', liked: false);
    await b;
  });

  test('마지막 글의 값은 그대로 표시한다', () async {
    final a = provider.loadUserActions('a', userId: 'me');
    repo.finish('a', liked: true, scrapped: true);
    await a;
    expect(provider.isCurrentPostLiked, isTrue);
    expect(provider.isCurrentPostScrapped, isTrue);
  });
}
