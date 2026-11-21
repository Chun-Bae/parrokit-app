// 단어 복습을 마치면 본 단어를 결과로 보여 주고, 받은 크래커를 '짜잔' 하고
// 띄운다(5차 509, 사용자 요청).
//
// 전에는 '알아요 N개 · 다시 M개' 한 줄과 크래커 한 줄이 끝이라, 어떤 단어를
// 틀렸는지 보려면 목록으로 돌아가 하나씩 열어야 했고 받은 크래커도 눈에 잘
// 띄지 않았다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/reward_celebration.dart';

void main() {
  testWidgets('덮개는 받은 크래커 수를 크게 적는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRewardCelebration(context, crackers: 7),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('reward-celebration')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('reward-celebration-title')), findsOneWidget);
    expect(find.textContaining('7'), findsOneWidget);
  });

  // 흰 카드 없이 어두운 막 위에 바로 올린다(5차 515, 사용자 요청).
  testWidgets('덮개에는 흰 배경 카드가 없다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRewardCelebration(context, crackers: 5),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final boxes = tester
        .widgetList<Container>(find.descendant(
          of: find.byKey(const ValueKey('reward-celebration')),
          matching: find.byType(Container),
        ))
        .where((c) => c.decoration is BoxDecoration);
    for (final box in boxes) {
      final color = (box.decoration as BoxDecoration).color;
      expect(color == null || color.a == 0, isTrue,
          reason: '덮개 안에 칠한 배경이 남아 있으면 안 된다');
    }

    final title = tester.widget<Text>(
        find.byKey(const ValueKey('reward-celebration-title')));
    expect(title.style?.color, Colors.white);
  });

  testWidgets('크래커가 없으면 덮개를 띄우지 않는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRewardCelebration(context, crackers: 0),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('reward-celebration')), findsNothing);
  });

  testWidgets('눌러서 닫을 수 있다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRewardCelebration(context, crackers: 3),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('reward-celebration')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reward-celebration')), findsNothing);
  });

  test('복습 마친 화면이 본 단어를 적고 덮개를 띄운다', () {
    final code = File(
            'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');

    // 본 단어와 고른 답을 들고 있다가 마친 화면에 적는다.
    expect(code, contains('answered.add('));
    expect(code, contains("ValueKey('review-result-list')"));
    // 한 바퀴에 한 번만 띄운다.
    expect(code, contains('showRewardCelebration('));
    expect(code, contains('celebrated = true'));
    // '다시' 고른 것만 다시 돌 때는 지난 바퀴 결과를 비운다.
    expect(code, contains('answered.clear()'));
  });
}
