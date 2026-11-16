// 알림 메뉴에서 흐려진 줄은 왜 못 누르는지 말한다(5차 347).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  required bool enabled,
  String? reason,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCommunityOptionsSheet(
            context: context,
            title: '알림 메뉴',
            actions: [
              CommunityOptionAction(
                label: '모두 읽음',
                enabled: enabled,
                disabledReason: reason,
                onTap: () async {},
              ),
            ],
          ),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('못 누르는 줄에는 까닭이 함께 보인다', (tester) async {
    await _openSheet(tester, enabled: false, reason: '읽지 않은 알림이 없어요.');
    expect(find.text('모두 읽음'), findsOneWidget);
    expect(find.text('읽지 않은 알림이 없어요.'), findsOneWidget);
  });

  testWidgets('누를 수 있으면 까닭을 적지 않는다', (tester) async {
    await _openSheet(tester, enabled: true, reason: '읽지 않은 알림이 없어요.');
    expect(find.text('읽지 않은 알림이 없어요.'), findsNothing);
  });

  test('알림 화면이 두 줄 모두에 까닭을 준다', () {
    final code = File(
            'lib/features/community/notification/presentation/community_notification_screen.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains("disabledReason: '읽지 않은 알림이 없어요.'"));
    expect(code, contains("disabledReason: '지울 알림이 없어요.'"));
  });
}
