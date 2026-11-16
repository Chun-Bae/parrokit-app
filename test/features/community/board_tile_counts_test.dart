// 목록 글 줄의 조회·공감·댓글 수. 아이콘만 있어서 화면 읽기로는 숫자만
// 읽혔다(5차). 상세 화면은 이미 이름을 붙여 놓았다.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/features/community/shell/presentation/widgets/community_board_post_tile.dart';
import 'package:provider/provider.dart';

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  @override
  AppUser? get currentUser => AppUser(id: 'u1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('조회·공감·댓글 수를 이름과 함께 읽어 준다', (tester) async {
    final handle = tester.ensureSemantics();
    final firestore = FakeFirebaseFirestore();

    final post = Post(
      id: 'p1',
      postType: 'board',
      category: '자유',
      title: '안녕하세요.',
      content: '잘 부탁드립니다.',
      authorId: 'u2',
      authorNickname: 'ch',
      snippet: '잘 부탁드립니다.',
      viewCount: 14,
      likeCount: 2,
      commentCount: 6,
      createdAt: DateTime(2026, 8, 4),
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<CommunityProvider>(
          create: (_) => CommunityProvider(
            repository: CommunityRepository(firestore: firestore),
            userService: FirebaseUserService(firestore: firestore),
          ),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => _FakeUserProvider(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CommunityBoardPostTile(post: post)),
      ),
    ));
    await tester.pump();

    // 눈으로는 숫자만 보이지만, 화면 읽기에는 이름이 붙는다.
    expect(find.text('14'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('조회 14')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('공감 2')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('댓글 6')), findsOneWidget);

    handle.dispose();
  });
}
