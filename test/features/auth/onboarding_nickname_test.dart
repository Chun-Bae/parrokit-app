import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/shared/utils/nickname_rule.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/auth/onboarding/onboarding_screen.dart';

/// 온보딩 화면이 쓰는 것만 흉내 낸다(닉네임 중복 확인, 로딩 여부).
class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  bool available = true;
  bool fail = false;

  @override
  bool get isLoading => false;

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    if (fail) throw Exception('network');
    return available;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(UserProvider user) => ChangeNotifierProvider<UserProvider>.value(
      value: user,
      child: const MaterialApp(home: OnboardingScreen()),
    );

void main() {
  testWidgets('중복 확인이 실패하면 왜 안 됐는지 화면에 뜬다', (tester) async {
    final user = _FakeUserProvider()..fail = true;

    await tester.pumpWidget(_app(user));
    await tester.enterText(find.byType(TextFormField), '춘배');
    await tester.pump();
    await tester.tap(find.text('중복 확인'));
    await tester.pump();
    await tester.pump();

    // 전에는 실패 때 _hasCheckedNickname을 false로 두는 바람에 안내가 가려져,
    // 확인을 눌러도 아무 일도 없는 것처럼 보였다.
    expect(find.text('닉네임을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
  });

  testWidgets('쓸 수 있는 닉네임과 이미 쓰는 닉네임을 구분해 알린다', (tester) async {
    final user = _FakeUserProvider();

    await tester.pumpWidget(_app(user));
    await tester.enterText(find.byType(TextFormField), '춘배');
    await tester.pump();
    await tester.tap(find.text('중복 확인'));
    await tester.pump();
    await tester.pump();
    expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);

    user.available = false;
    await tester.enterText(find.byType(TextFormField), '다른이름');
    await tester.pump();
    // 글자를 바꾸면 앞 결과는 지워진다
    expect(find.text('사용 가능한 닉네임입니다.'), findsNothing);
    await tester.tap(find.text('중복 확인'));
    await tester.pump();
    await tester.pump();
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
  });

  testWidgets('온보딩 닉네임도 프로필 수정과 같은 길이까지만 쳐진다', (tester) async {
    final user = _FakeUserProvider();

    await tester.pumpWidget(_app(user));
    final tooLong = '가' * (nicknameMaxLength + 5);
    await tester.enterText(find.byType(TextFormField), tooLong);
    await tester.pump();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text.length, nicknameMaxLength);
  });
}
