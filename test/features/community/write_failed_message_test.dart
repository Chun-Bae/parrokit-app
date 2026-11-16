// 글을 올리지 못했을 때는 사라지는 토스트 대신 창으로 말한다(5차 308).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/write_failed_message.dart';

const writeScreens = [
  'lib/features/community/board/presentation/board_write_screen.dart',
  'lib/features/community/question/presentation/question_write_screen.dart',
  'lib/features/community/vote/presentation/vote_write_screen.dart',
];

String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('올리지 못한 것과 로그인 안내는 창으로 띄운다', () {
    // 2.5초 토스트를 놓치면 글이 올라간 줄 알고 화면을 닫는다.
    for (final path in writeScreens) {
      final code = _flat(File(path).readAsStringSync());
      // 말은 communityLoginRequiredText 한 곳에서 정한다(5차 312).
      expect(
          code,
          contains(
              'showWriteFailedMessage(context, communityLoginRequiredText)'),
          reason: path);
      expect(
          code,
          matches(RegExp(r'showWriteFailedMessage\( ?context, '
              r'[a-zA-Z]*[Pp]rovider\.errorMessage')),
          reason: path);
    }
  });

  test('가벼운 안내는 토스트 그대로 쓴다', () {
    // 창을 띄우면 태그 하나 넣을 때마다 확인을 눌러야 한다.
    final board = _flat(File(writeScreens[0]).readAsStringSync());
    expect(board, contains("showToast('사진은 5장까지 넣을 수 있어요.')"));
    expect(board, contains("showToast('태그는 20개까지 붙일 수 있어요.')"));
  });

  testWidgets('창에 말이 적히고 확인을 누르면 닫힌다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showWriteFailedMessage(context, '올리지 못했어요.'),
            child: const Text('열기'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('write-failed-dialog')), findsOneWidget);
    expect(find.text('올리지 못했어요.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('write-failed-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('write-failed-dialog')), findsNothing);
  });
}
