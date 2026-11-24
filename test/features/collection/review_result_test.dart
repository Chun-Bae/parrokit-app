// 단어 복습을 마치면 본 단어를 결과로 보여 주고, 받은 크래커를 '짜잔' 하고
// 띄운다(5차 509, 사용자 요청).
//
// 전에는 '알아요 N개 · 다시 M개' 한 줄과 크래커 한 줄이 끝이라, 어떤 단어를
// 틀렸는지 보려면 목록으로 돌아가 하나씩 열어야 했고 받은 크래커도 눈에 잘
// 띄지 않았다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/assist_icon.dart';
import 'package:parrokit/core/shared/widgets/currency_icon.dart';
import 'package:parrokit/core/shared/widgets/reward_celebration.dart';

void main() {
  testWidgets('덮개는 받은 크래커 수를 크게 적는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRewardCelebration(context, amount: 7),
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
            onPressed: () => showRewardCelebration(context, amount: 5),
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
            onPressed: () => showRewardCelebration(context, amount: 0),
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
            onPressed: () => showRewardCelebration(context, amount: 3),
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


  // 광고를 보고 받는 패롯도 같은 덮개로 띄운다(5차 568, 사용자 요청).
  // 토스트 한 줄은 광고가 닫히는 어수선한 순간에 묻혔다.
  testWidgets('재화에 맞는 그림과 말을 보여 준다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRewardCelebration(context,
                amount: 3, currency: Currency.parrot),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('패롯 +3'), findsOneWidget);
    final icon = tester.widget<CurrencyIcon>(find.byType(CurrencyIcon));
    expect(icon.currency, Currency.parrot);
  });

  test('재화마다 적는 말이 다르다', () {
    expect(rewardCelebrationAmount(Currency.parrot, 3), '패롯 +3');
    // 크래커는 연습 보상과 같은 꼴을 그대로 쓴다.
    expect(rewardCelebrationAmount(Currency.cracker, 7), contains('크래커'));
  });

  test('광고 보상이 이 덮개를 쓴다', () {
    final source = File(
      'lib/features/settings/more/presentation/sections/ad_reward_button.dart',
    ).readAsStringSync();
    expect(source, contains('showRewardCelebration('));
    expect(source, contains('Currency.parrot'));
  });

  // 서버 지급으로 옮기면서 출시 빌드에서 덮개가 통째로 사라졌다(5차). 글
  // 한 줄만 남아 '왜 안 나오냐'는 말이 나왔다. 덮개는 사용자가 원해서 넣은
  // 것이다. 잔액이 실제로 오르기를 기다렸다가 띄운다.
  test('서버가 지급해도 덮개를 띄운다', () {
    final source = File(
      'lib/features/settings/more/presentation/sections/ad_reward_button.dart',
    ).readAsStringSync();
    final branch = source.substring(source.indexOf('serverCreditsReward)'));
    final waited = branch.indexOf('_waitForCoins(');
    final shown = branch.indexOf('showRewardCelebration(');
    expect(waited, greaterThan(-1), reason: '잔액이 오르기를 기다린다');
    expect(shown, greaterThan(-1), reason: '기다린 뒤 덮개를 띄운다');
    expect(waited, lessThan(shown), reason: '기다리기가 먼저다');
  });

  // 뜻·발음·원문과 예문 몫도 패롯을 내고 받는 것이라 같은 덮개로 띄운다
  // (5차, 사용자 요청).
  testWidgets('산 몫도 그 몫의 그림으로 띄운다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAssistCelebration(context,
                amount: 10, kind: AssistKind.example),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('예문 +10'), findsOneWidget);
    final icon = tester.widget<AssistIcon>(find.byType(AssistIcon));
    expect(icon.kind, AssistKind.example);
  });

  test('몫 사기가 이 덮개를 쓴다', () {
    final source = File(
      'lib/features/settings/more/presentation/sections/assist_usage_section.dart',
    ).readAsStringSync();
    expect(source, contains('showAssistCelebration('));
    expect(source, contains('AssistKind.meaning'));
    expect(source, contains('AssistKind.example'));
  });

  // 기다리는 동안도 덮개로 보여 준다(5차, 사용자 요청). 토스트 한 줄은
  // 광고가 닫히는 어수선한 순간에 묻혔다.
  testWidgets('받는 중 덮개는 끝나면 스스로 닫히고 값을 돌려준다', (tester) async {
    final gate = Completer<bool>();
    Future<bool>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showRewardPending<bool>(
              context,
              until: gate.future,
              icon: const CurrencyIcon(Currency.parrot, size: 56),
              text: '패롯 +3',
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();

    expect(find.byKey(const ValueKey('reward-pending')), findsOneWidget);
    expect(find.text('받는 중'), findsOneWidget);
    expect(find.text('패롯 +3'), findsOneWidget);

    gate.complete(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reward-pending')), findsNothing);
    expect(await result, isTrue);
  });

  // 광고를 틀 때 서버를 미리 깨우고, 끝나면 기다리는 덮개를 띄운 뒤
  // 들어오면 '짜잔'으로 바꾼다.
  test('광고 보상이 미리 깨우고 기다리는 덮개를 거친다', () {
    final source = File(
      'lib/features/settings/more/presentation/sections/ad_reward_button.dart',
    ).readAsStringSync();
    final warm = source.indexOf('warmUpRewardServer()');
    final pending = source.indexOf('showRewardPending<bool>(');
    final done = source.indexOf('showRewardCelebration(');
    expect(warm, greaterThan(-1), reason: '광고 틀기 전에 깨운다');
    expect(pending, greaterThan(-1), reason: '기다리는 덮개를 띄운다');
    expect(warm, lessThan(pending), reason: '깨우기가 먼저다');
    expect(pending, lessThan(done), reason: '기다린 뒤에 짜잔이다');
  });
}
