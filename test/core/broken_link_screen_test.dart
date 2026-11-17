// 열 수 없는 링크로 들어와도 갇히지 않는다(5차 440).
//
// 라우터는 'voteId가 필요합니다.'처럼 개발자에게 하는 말만 적힌 빈 화면을
// 띄웠다. 앱바도 단추도 없어서, 알림을 눌러 바로 들어온 경우처럼 뒤로 갈
// 곳이 없으면 거기서 멈춘다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/broken_link_screen.dart';

void main() {
  test('라우터에 개발자용 안내가 남아 있지 않다', () {
    final code = File('lib/core/app/router/app_router.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    for (final gone in ['voteId가 필요합니다', 'questionId가 필요합니다', 'postId가 필요합니다', 'clipId가 필요합니다']) {
      expect(code, isNot(contains(gone)), reason: gone);
    }
    expect(code, contains('BrokenLinkScreen()'));
  });

  test('무엇이 잘못됐는지 적고 홈으로 보내 준다', () {
    expect(brokenLinkMessage, contains('열 수 없는 주소'));
    expect(brokenLinkHomeLabel, '홈으로 가기');
  });

  testWidgets('홈으로 가기를 누르면 홈으로 간다', (tester) async {
    var wentHome = false;
    final router = GoRouter(
      initialLocation: '/broken',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) {
            wentHome = true;
            return const Scaffold(body: Text('홈'));
          },
        ),
        GoRoute(path: '/broken', builder: (_, __) => const BrokenLinkScreen()),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text(brokenLinkMessage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('broken-link-home')));
    await tester.pumpAndSettle();
    expect(wentHome, isTrue);
  });
}
