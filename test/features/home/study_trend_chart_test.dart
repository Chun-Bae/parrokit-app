// 날짜별 학습 그래프(사용자 요청).
//
// 캘린더 칸 색은 네 단계뿐이라 15번 한 날과 50번 한 날이 같아 보인다.
// 그래프는 날짜별 높이로 얼마나 했는지 보여 준다. 쉰 날도 0으로 넣어야
// 그래프에서 사라지지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/study_trend_chart.dart';

void main() {
  final now = DateTime(2026, 11, 21, 15, 30);

  group('날짜 만들기', () {
    test('오늘까지 거꾸로 세어 과거부터 늘어놓는다', () {
      final days = studyTrendDays(now: now, days: 7);

      expect(days.length, 7);
      expect(days.first.date, DateTime(2026, 11, 15));
      expect(days.last.date, DateTime(2026, 11, 21));
    });

    test('기록이 없는 날도 0으로 넣는다', () {
      final days = studyTrendDays(
        now: now,
        days: 3,
        practiceCounts: const {'2026-11-21': 4},
      );

      expect(days.map((d) => d.practiced).toList(), [0, 0, 4]);
      expect(days[0].isEmpty, isTrue);
      expect(days[2].isEmpty, isFalse);
    });

    test('따라 말하기와 단어 복습을 함께 센다', () {
      final days = studyTrendDays(
        now: now,
        days: 2,
        practiceCounts: const {'2026-11-21': 3},
        wordReviewCounts: const {'2026-11-21': 8, '2026-11-20': 2},
      );

      expect(days[0].total, 2);
      expect(days[1].practiced, 3);
      expect(days[1].words, 8);
      expect(days[1].total, 11);
    });

    test('시각이 몇 시든 날짜만 본다', () {
      final late = studyTrendDays(now: DateTime(2026, 11, 21, 23, 59), days: 1);
      final early = studyTrendDays(now: DateTime(2026, 11, 21, 0, 1), days: 1);

      expect(late.single.date, early.single.date);
    });
  });

  group('간추리는 말', () {
    test('한 날도 없으면 학습 0일', () {
      final days = studyTrendDays(now: now, days: 5);
      expect(studyTrendSummary(days), '학습 0일 · 따라 말하기 0번');
    });

    test('단어를 복습한 날만 단어를 적는다', () {
      final days = studyTrendDays(
        now: now,
        days: 3,
        practiceCounts: const {'2026-11-20': 2},
        wordReviewCounts: const {'2026-11-21': 5},
      );
      expect(studyTrendSummary(days), '학습 2일 · 따라 말하기 2번 · 단어 5개');
    });

    test('쉰 날은 쉰 날이라고 읽어 준다', () {
      final day = StudyTrendDay(date: _nov20, practiced: 0, words: 0);
      expect(studyTrendDayLabel(day, now: now), '11월 20일, 쉰 날');
    });

    test('한 날은 두 수를 함께 읽어 준다', () {
      final day = StudyTrendDay(date: _nov20, practiced: 3, words: 7);
      expect(studyTrendDayLabel(day, now: now), '11월 20일, 따라 말하기 3번, 단어 7개');
    });

    test('단어를 안 한 날은 단어를 안 적는다', () {
      final day = StudyTrendDay(date: _nov20, practiced: 3, words: 0);
      expect(studyTrendDayLabel(day, now: now), '11월 20일, 따라 말하기 3번');
    });
  });

  group('화면', () {
    Future<void> pump(
      WidgetTester tester, {
      Map<String, int> counts = const {},
      Map<String, int> words = const {},
    }) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudyTrendChart(
                practiceCounts: counts,
                wordReviewCounts: words,
                now: now,
              ),
            ),
          ),
        ));

    testWidgets('기록이 없으면 그렇게 말한다', (tester) async {
      await pump(tester);
      expect(find.text(studyTrendEmptyHint), findsOneWidget);
    });

    testWidgets('기록이 있으면 간추린 줄을 적는다', (tester) async {
      await pump(tester,
          counts: const {'2026-11-21': 4}, words: const {'2026-11-20': 6});

      final text = tester
          .widget<Text>(find.byKey(const ValueKey('trend-summary')))
          .data!;
      expect(text, contains('학습 2일'));
      expect(text, contains('따라 말하기 4번'));
      expect(text, contains('단어 6개'));
    });

    testWidgets('막대를 누르면 그날 수를 적고, 다시 누르면 돌아간다', (tester) async {
      await pump(tester, counts: const {'2026-11-21': 4});

      await tester.tap(find.byTooltip('11월 21일, 따라 말하기 4번'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend-summary'))).data,
        '11월 21일, 따라 말하기 4번',
      );

      await tester.tap(find.byTooltip('11월 21일, 따라 말하기 4번'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend-summary'))).data,
        contains('학습 1일'),
      );
    });

    testWidgets('기간을 바꾸면 그만큼 본다', (tester) async {
      // 기본 14일 밖이라 처음에는 안 보이는 날.
      await pump(tester, counts: const {'2026-11-01': 9});

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend-summary'))).data,
        studyTrendEmptyHint,
      );

      await tester.tap(find.byKey(const ValueKey('trend-range-30')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend-summary'))).data,
        contains('따라 말하기 9번'),
      );
    });
  });
}

final _nov20 = DateTime(2026, 11, 20);
