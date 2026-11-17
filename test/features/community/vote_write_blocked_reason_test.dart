// 투표 만들기에서 무엇이 빠졌는지 화면에 뜨는지 본다(5차 442).
//
// 433에서 '고를 보기를 2개 넘게 적어 주세요'(조건과 어긋남)를
// '항목을 2개 이상 적어 주세요.'로 고치고, 434에서 이름을 '항목'으로
// 맞췄다. 그런데 **둘 다 기기에서 띄워 보지 못해 미확인으로 남아 있었다**
// (보기를 지워야 뜬다). 화면을 진짜로 그려서 확인한다.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/community/shared/presentation/write_blocked_reason.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/features/community/vote/presentation/vote_write_screen.dart';
import 'package:provider/provider.dart';

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  @override
  AppUser? get currentUser => AppUser(id: 'u1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpScreen(WidgetTester tester) async {
  final firestore = FakeFirebaseFirestore();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<CommunityProvider>(
        create: (_) => CommunityProvider(
          repository: CommunityRepository(firestore: firestore),
          userService: FirebaseUserService(firestore: firestore),
        ),
      ),
      ChangeNotifierProvider<UserProvider>(create: (_) => _FakeUserProvider()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const VoteWriteScreen()),
  ));
  await tester.pump();
}

void main() {
  testWidgets('제목이 비면 제목부터 적으라고 한다', (tester) async {
    await _pumpScreen(tester);
    expect(find.text(writeNeedsTitleMessage), findsOneWidget);
  });

  testWidgets('빈 항목 칸이 있으면 채우라고 한다', (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '점심 뭐 먹지?');
    await tester.pump();

    // 제목만 채우면 그다음 빠진 것을 말한다.
    expect(find.text(writeNeedsTitleMessage), findsNothing);
    expect(
      find.text(writeNeedsContentMessage).evaluate().isNotEmpty ||
          find.text(writeNeedsFilledOptionsMessage).evaluate().isNotEmpty,
      isTrue,
      reason: '내용이나 빈 항목 칸 중 하나를 말해야 한다',
    );
  });

  testWidgets("안내가 '보기'가 아니라 '항목'이라고 부른다", (tester) async {
    await _pumpScreen(tester);
    // 화면이 쓰는 이름과 같아야 한다('투표 대상 항목', '항목 추가하기').
    expect(find.textContaining('보기'), findsNothing);
    expect(writeNeedsTwoOptionsMessage, contains('항목'));
    expect(writeNeedsFilledOptionsMessage, contains('항목'));
  });
}
