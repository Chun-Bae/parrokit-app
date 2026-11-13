import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/features/community/shell/data/debug_fake_community.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

void main() {
  test('테스트 실행에서는 가짜 커뮤니티가 꺼져 있다', () {
    // --dart-define을 주지 않으면 꺼진다. 출시 빌드는 kDebugMode가 false라 항상 꺼진다.
    expect(kFakeCommunity, isFalse);
  });

  test('가짜 글은 모두 가짜 표시 id를 쓴다', () {
    for (final type in ['board', 'question', 'vote']) {
      final posts = fakeCommunityPosts(type, now: DateTime(2026, 11, 13));
      expect(posts, isNotEmpty, reason: type);
      expect(posts.every((p) => isFakePost(p.id) && p.postType == type), isTrue,
          reason: type);
    }
    expect(
        fakeCommunityPosts('question').map((p) => p.questionStatus).toSet(),
        containsAll(['waiting', 'resolved']));
  });

  test('가짜 글에 공감·스크랩·투표·댓글·조회수를 눌러도 서버에 아무것도 쓰지 않는다',
      () async {
    final firestore = FakeFirebaseFirestore();
    final provider = CommunityProvider(
      repository: CommunityRepository(firestore: firestore),
      userService: FirebaseUserService(firestore: firestore),
    );
    final id = fakeCommunityPosts('vote').first.id;
    final before = firestore.dump();

    await provider.incrementViewCount(id, userId: 'u1');
    await provider.toggleLike(id, 'u1');
    await provider.toggleScrap(id, 'u1');
    expect(await provider.votePost(id, 0, 'u1'), isFalse);
    expect(
        await provider.addComment(id, 'hi',
            authorId: 'u1', authorNickname: 'n'),
        isFalse);
    expect(await provider.deletePost(id), isFalse);

    expect(firestore.dump(), before);
  });

  test('로그인하지 않은 공감·스크랩은 서버에 쓰지 않는다', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('posts').doc('q1').set({'likeCount': 0});
    final provider = CommunityProvider(
      repository: CommunityRepository(firestore: firestore),
      userService: FirebaseUserService(firestore: firestore),
    );
    final before = firestore.dump();
    await provider.toggleLike('q1', '');
    await provider.toggleScrap('q1', '');
    expect(firestore.dump(), before);
  });
}
