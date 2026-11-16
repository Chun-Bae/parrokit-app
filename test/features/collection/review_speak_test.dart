// 복습 카드에서도 발음을 들을 수 있다(5차 329).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/speak_controls.dart';

void main() {
  testWidgets('반복을 끄면 듣기 단추만 보인다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SpeakControls(text: 'huge', language: '영어', showRepeat: false),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('speak-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-text')), findsNothing);
  });

  testWidgets('기본은 듣기와 반복 둘 다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SpeakControls(text: 'huge', language: '영어')),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('speak-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-text')), findsOneWidget);
  });

  test('복습 카드가 그 위젯을 쓴다', () {
    final code = File(
            'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains("ValueKey('speak-review-word')"));
    expect(code, contains('showRepeat: false'));
  });
}
