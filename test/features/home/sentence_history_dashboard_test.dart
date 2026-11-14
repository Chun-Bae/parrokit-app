import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/sentence_history_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기본으로 주던 예시 문장을 없앴으므로(5차) 테스트가 내 문장을 넣어 둔다.
const _texts = [
  'Hello there!',
  'How was your day?',
  'Can I get a coffee?',
  'Nice to meet you.',
  'Thank you so much.',
];

String idOf(String text) => MySentenceStore.idFor('영어', text);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MySentenceStore.cloud = null;
    for (final text in _texts) {
      await MySentenceStore.add('guest', language: '영어', text: text);
    }
  });

  testWidgets('듣기와 따라 말하기가 쌓이면 대시보드 숫자가 바로 오른다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SentenceHistoryDashboard(
                    accountId: 'guest', language: '영어')))));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.textContaining('아직 연습한 문장이 없어요'), findsOneWidget);

    await tester.runAsync(() async {
      await SentenceActivityStore.incrementListen(
          'guest', idOf('Hello there!'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('1회'), findsOneWidget);
    expect(find.text('듣기'), findsOneWidget);
    expect(find.text('연습한 문장'), findsOneWidget);

    await tester.runAsync(() async {
      await SentenceActivityStore.incrementPractice(
          'guest', idOf('Hello there!'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('Hello there!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('새 디자인(compact)은 최근 문장을 3개까지만 보여주고 추천 문장은 뺀다',
      (tester) async {
    await tester.runAsync(() async {
      for (final text in _texts) {
        await SentenceActivityStore.incrementPractice('guest', idOf(text));
      }
    });
    Widget build(bool compact) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SentenceHistoryDashboard(
                    accountId: 'guest', language: '영어', compact: compact))));

    int shown() => _texts.where((t) => find.text(t).evaluate().isNotEmpty).length;

    await tester.pumpWidget(build(false));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(shown(), greaterThan(3));

    await tester.pumpWidget(build(true));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('최근 연습한 문장'), findsOneWidget);
    expect(find.text('따라 말해보면 좋은 문장'), findsNothing);
    expect(shown(), 3);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('최고 점수 꼬리말은 0%면 붙이지 않는다', () {
    expect(bestScoreLabel(null), '');
    expect(bestScoreLabel(0), '');
    expect(bestScoreLabel(0.004), '');
    expect(bestScoreLabel(0.86), ' · 최고 86%');
  });
}
