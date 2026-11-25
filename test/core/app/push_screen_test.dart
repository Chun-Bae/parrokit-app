// 화면을 미는 길이 하나다(5차, 사용자 요청).
//
// 아래 탭 바는 AppShell이 그린다. 탭 안쪽 Navigator로 밀면 민 화면 아래에
// 탭 바가 남아서, 이용 약관을 열어도 탭 바가 보이고 거기서 다른 탭을 누를
// 수 있었다. 눈에 띌 때마다 그 자리에서만 rootNavigator: true를 붙여 왔고
// (wallet_section에 그 주석이 남아 있다), 자리가 늘수록 빠뜨리는 곳이
// 생겼다. 이 테스트가 다시 흩어지는 것을 막는다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/app/navigation/push_screen.dart';

/// lib 아래 모든 Dart 파일.
List<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('MaterialPageRoute를 직접 만드는 곳이 없다', () {
    final offenders = <String>[];
    for (final file in _libFiles()) {
      if (file.path.endsWith('push_screen.dart')) continue;
      if (file.readAsStringSync().contains('MaterialPageRoute(')) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: '화면은 pushAppScreen으로 민다. 직접 밀면 탭 바가 남는다:\n'
          '${offenders.join('\n')}',
    );
  });

  test('미는 길은 root navigator를 쓴다', () {
    final src =
        File('lib/core/app/navigation/push_screen.dart').readAsStringSync();
    expect(src, contains('rootNavigator: true'));
  });

  testWidgets('민 화면이 셸 위를 덮는다', (tester) async {
    // 셸 흉내: 바깥 Navigator(root) 아래에 안쪽 Navigator와 탭 바를 둔다.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (inner) => Center(
              child: TextButton(
                onPressed: () =>
                    pushAppScreen(inner, const Text('민 화면')),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
        bottomNavigationBar: const Text('탭 바'),
      ),
    ));

    expect(find.text('탭 바'), findsOneWidget);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('민 화면'), findsOneWidget);
    // root로 밀었으니 셸째로 덮인다. 탭 바는 트리에서 사라진다.
    expect(find.text('탭 바'), findsNothing);
  });
}
