// 학습 캘린더에 단어 복습 개수도 적는다(사용자 요청).
//
// 따라 말하기와 섞지 않는다. 하루 목표와 칸 색은 따라 말한 수로 재는데,
// 단어까지 그 수에 넣으면 단어만 넘겨도 '목표 완료'가 되어 버린다.
// 두 수를 나란히 적기만 한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/study_garden_preview.dart';

void main() {
  final now = DateTime(2026, 11, 21);

  Future<void> pump(
    WidgetTester tester, {
    Map<String, int> counts = const {},
    Map<String, int> words = const {},
    Map<String, int> goals = const {},
  }) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudyGardenPreview(
              practiceCounts: counts,
              practiceGoals: goals,
              wordReviewCounts: words,
              dailyGoal: 5,
              now: now,
            ),
          ),
        ),
      ));

  testWidgets('머리에 그달 단어 복습 수를 적는다', (tester) async {
    await pump(tester, counts: const {
      '2026-11-20': 2,
    }, words: const {
      '2026-11-19': 4,
      '2026-11-20': 8,
      // 지난 달 것은 11월 수에 들어가지 않는다.
      '2026-10-30': 100,
    });

    expect(find.text('11월 2번'), findsOneWidget);
    expect(find.text('단어 12개'), findsOneWidget);
  });

  testWidgets('복습한 단어가 없으면 그 칸을 적지 않는다', (tester) async {
    await pump(tester, counts: const {'2026-11-20': 2});

    expect(find.text('11월 2번'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-month-words')), findsNothing);
  });

  testWidgets('날짜를 누르면 그날 복습한 단어 수도 적는다', (tester) async {
    await pump(tester,
        counts: const {'2026-11-20': 2}, words: const {'2026-11-20': 7});

    await tester.tap(find.byTooltip(
        '11월 20일, 2번 연습, 단어 7개 복습'));
    await tester.pumpAndSettle();

    expect(find.textContaining('단어 7개'), findsWidgets);
  });

  testWidgets('단어만 복습한 날은 목표 완료가 되지 않는다', (tester) async {
    await pump(tester, words: const {'2026-11-20': 50});

    // 따라 말한 수가 0이라 '목표 완료'가 아니다.
    expect(find.byTooltip('11월 20일, 0번 연습, 단어 50개 복습'), findsOneWidget);
    expect(find.text('학습 0일 · 목표 완료 0일'), findsOneWidget);
  });
}
