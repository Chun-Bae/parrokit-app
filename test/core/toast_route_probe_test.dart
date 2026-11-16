// 셸 밖 전체 화면 라우트에서 토스트가 보이는지(5차 안건 좁히기).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

void main() {
  testWidgets('셸 밖 라우트에서도 토스트가 보인다', (tester) async {
    final router = GoRouter(
      initialLocation: '/write',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(
            body: child,
            bottomNavigationBar: const SizedBox(height: 60),
          ),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const Center(child: Text('홈')),
            ),
          ],
        ),
        GoRoute(
          path: '/write',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              actions: [
                TextButton(
                  onPressed: () => showToast('테스트'),
                  child: const Text('완료'),
                ),
              ],
            ),
            body: const SizedBox.expand(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('완료'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('테스트'), findsOneWidget);
  });
}
