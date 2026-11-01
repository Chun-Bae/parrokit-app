import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/features/home/dashboard/presentation/add_sentence_screen.dart';

Future<void> open(WidgetTester tester, String language) =>
    tester.pumpWidget(MaterialApp(home: AddSentenceScreen(language: language)));

/// 서버가 알려 준 하루 한도와 남은 횟수를 흉내 낸다.
class _UsageAssist implements SentenceAssist {
  _UsageAssist({required this.dailyLimit, required this.remainingToday});

  @override
  int? dailyLimit;
  @override
  int? remainingToday;

  @override
  Future<void> refreshUsage() async {}

  @override
  Future<SentenceSuggestion> suggest(
          {required String language, required String text}) async =>
      const SentenceSuggestion(translation: '안녕');

  @override
  Future<String?> transliterate(
          {required String language, required String hangul}) async =>
      null;
}

void main() {
  testWidgets('영어에는 한글 전사칸이 없다', (tester) async {
    await open(tester, '영어');
    expect(find.byKey(const ValueKey('sentence-hangul')), findsNothing);
    expect(find.byKey(const ValueKey('auto-fill-now')), findsOneWidget);
  });

  testWidgets('일본어는 한글 전사칸이 있고 준비 중이면 안내한다', (tester) async {
    await open(tester, '일본어');
    await tester.enterText(
        find.byKey(const ValueKey('sentence-hangul')), '곤니치와');
    await tester.tap(find.byKey(const ValueKey('transliterate')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('transliterate-message')), findsOneWidget);
    expect(find.textContaining('쓸 수 없어요'), findsWidgets);
  });

  testWidgets('채우기 버튼은 원문이 있어야 켜지고, 연결 전이면 안내하고 직접 입력할 수 있다', (tester) async {
    await open(tester, '영어');
    FilledButton fill() => tester
        .widget<FilledButton>(find.byKey(const ValueKey('auto-fill-now')));
    expect(fill().onPressed, isNull);
    // 횟수를 못 읽었어도 아무것도 안 보이지 않고 안내를 보여준다.
    await tester.pump();
    expect(find.byKey(const ValueKey('usage-count')), findsNothing);
    expect(find.byKey(const ValueKey('usage-unknown')), findsOneWidget);
    expect(find.textContaining('횟수를 확인하지 못했어요'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('sentence-text')), 'Hello');
    await tester.pump();
    expect(fill().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('auto-fill-now')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('자동 채우기를 쓸 수 없어요'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('sentence-translation')), '안녕');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-sentence')))
            .onPressed,
        isNotNull);
  });

  testWidgets('입력하면 자동으로 채우기 스위치는 없다', (tester) async {
    await open(tester, '영어');
    expect(find.byKey(const ValueKey('auto-fill-switch')), findsNothing);
    expect(find.textContaining('자동으로 채우기'), findsNothing);
  });

  testWidgets('언어를 고르면 한글 전사칸이 나타나고 사라진다', (tester) async {
    await open(tester, '영어');
    expect(find.byKey(const ValueKey('sentence-hangul')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sentence-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('일본어').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sentence-hangul')), findsOneWidget);
  });

  testWidgets('서버가 알려 준 횟수를 버튼 옆에 "쓴 횟수 / 한도"로 보여준다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AddSentenceScreen(
            language: '영어',
            assist: _UsageAssist(dailyLimit: 3, remainingToday: 2))));
    await tester.pump();
    expect(find.byKey(const ValueKey('usage-count')), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.textContaining('남았어요'), findsNothing);
  });

  testWidgets('횟수를 모두 쓰면 3 / 3이 되고 채우기 버튼이 꺼진다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AddSentenceScreen(
            language: '영어',
            assist: _UsageAssist(dailyLimit: 3, remainingToday: 0))));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('sentence-text')), 'Hello');
    await tester.pump();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('auto-fill-now')))
            .onPressed,
        isNull);
  });
}
