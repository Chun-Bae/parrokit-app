// 학습 캘린더의 '오늘'은 그릴 때마다 다시 본다(5차 377).
//
// 전에는 화면을 만들 때 한 번만 정해서, 앱을 켜 둔 채 자정을 넘기면 새 날이
// '아직 오지 않은 날'로 흐리게 보이고 눌리지도 않았다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/study_garden_preview.dart';

/// 날짜 칸의 안내 말(Semantics label)을 찾는다.
String labelOf(WidgetTester tester, String contains) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((w) => w.properties.label ?? '')
    .firstWhere((label) => label.contains(contains), orElse: () => '');

Widget _garden({required DateTime now, Map<String, int> counts = const {}}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StudyGardenPreview(
            practiceCounts: counts,
            practiceGoals: const {},
            dailyGoal: 5,
            totalPracticed: 0,
            now: now,
          ),
        ),
      ),
    );

void main() {
  testWidgets('오늘 연습한 날은 아직 오지 않은 날이 아니다', (tester) async {
    await tester.pumpWidget(_garden(
      now: DateTime(2026, 11, 17, 9),
      counts: {'2026-11-17': 3},
    ));
    await tester.pumpAndSettle();

    expect(labelOf(tester, '11월 17일'), '11월 17일, 3번 연습');
  });

  testWidgets('앞으로 올 날은 아직 오지 않은 날이라고 말한다', (tester) async {
    await tester.pumpWidget(_garden(now: DateTime(2026, 11, 17, 9)));
    await tester.pumpAndSettle();

    expect(labelOf(tester, '11월 18일'), '11월 18일, 아직 오지 않은 날');
  });

  testWidgets('자정을 넘겨 다시 그리면 새 날이 오늘이 된다', (tester) async {
    await tester.pumpWidget(_garden(
      now: DateTime(2026, 11, 17, 23, 59),
      counts: {'2026-11-18': 2},
    ));
    await tester.pumpAndSettle();
    expect(labelOf(tester, '11월 18일'), '11월 18일, 아직 오지 않은 날');

    // 날이 바뀐 뒤 같은 화면을 다시 그린다(앱을 켜 둔 채 자정을 넘긴 경우).
    await tester.pumpWidget(_garden(
      now: DateTime(2026, 11, 18, 0, 1),
      counts: {'2026-11-18': 2},
    ));
    await tester.pumpAndSettle();
    expect(labelOf(tester, '11월 18일'), '11월 18일, 2번 연습');
  });
}
