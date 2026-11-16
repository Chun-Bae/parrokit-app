// 글쓰기 화면에서 못 올렸다는 말이 실제로 보이는지(5차 307).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/write_failed_message.dart';

const writeScreens = [
  'lib/features/community/board/presentation/board_write_screen.dart',
  'lib/features/community/question/presentation/question_write_screen.dart',
  'lib/features/community/vote/presentation/vote_write_screen.dart',
];

void main() {
  test('세 글쓰기 화면은 토스트로 말하지 않는다', () {
    // 이 화면들에서는 토스트(SnackBar)가 실제 기기에서 그려지지 않았다.
    // 로그인 안내와 '올리지 못했어요'가 그렇게 조용히 사라졌다.
    for (final path in writeScreens) {
      final code = File(path).readAsStringSync();
      expect(code.contains('showToast('), isFalse, reason: path);
      expect(code, contains('showWriteFailedMessage('), reason: path);
    }
  });

  test('올리지 못한 까닭을 그대로 보여 준다', () {
    for (final path in writeScreens) {
      final code = File(path).readAsStringSync();
      expect(code, contains('로그인하고 다시 해 주세요.'), reason: path);
      expect(code, contains('errorMessage'), reason: path);
    }
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
