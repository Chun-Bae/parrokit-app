import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/auth/sign-in/sign_in_screen.dart';

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app() => ChangeNotifierProvider<UserProvider>.value(
      value: _FakeUserProvider(),
      child: const MaterialApp(home: SignInScreen()),
    );

void main() {
  testWidgets('아무 일도 하지 않던 자동 로그인 체크 상자는 없다', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    // 값을 어디에도 쓰지 않아서, 꺼도 로그인 상태가 그대로 남았다.
    expect(find.text('자동 로그인'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('소셜 로그인 단추마다 이름이 있다(화면 읽기·길게 누르기)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    for (final label in ['구글로 로그인', '카카오로 로그인', '네이버로 로그인', '애플로 로그인']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      expect(
        find.ancestor(
            of: find.byType(GestureDetector), matching: find.byTooltip(label)),
        findsOneWidget,
        reason: label,
      );
    }
  });
}
