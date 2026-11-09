import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/home/dashboard/presentation/home_palette.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/study_garden_preview.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/today_practice_summary.dart';

void main() {
  // MaterialApp은 테마 변경을 애니메이션으로 적용하므로(AnimatedTheme),
  // 밝기를 바꾼 뒤에는 애니메이션이 끝날 때까지 기다려야 새 색이 반영된다.
  Widget wrap(Brightness brightness, Widget Function() build) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(body: SingleChildScrollView(child: build())),
      );

  Color cardColor(WidgetTester tester, Type type) {
    final container = tester.widget<Container>(
      find
          .descendant(of: find.byType(type), matching: find.byType(Container))
          .first,
    );
    return ((container.decoration as BoxDecoration).color)!;
  }

  testWidgets('학습 캘린더 카드는 테마 밝기에 따라 배경색이 바뀐다', (tester) async {
    StudyGardenPreview build() => const StudyGardenPreview(
          practiceCounts: {},
          practiceGoals: {},
          dailyGoal: 5,
          totalPracticed: 0,
        );

    await tester.pumpWidget(wrap(Brightness.light, build));
    await tester.pumpAndSettle();
    expect(cardColor(tester, StudyGardenPreview), HomePalette.light.surface);

    await tester.pumpWidget(wrap(Brightness.dark, build));
    await tester.pumpAndSettle();
    expect(cardColor(tester, StudyGardenPreview), HomePalette.dark.surface);
  });

  testWidgets('오늘 연습 카드도 다크 모드에서 어두운 배경을 쓴다', (tester) async {
    TodayPracticeSummary build() => TodayPracticeSummary(
          completed: 1,
          goal: 5,
          total: 10,
          onEditGoal: () {},
        );

    await tester.pumpWidget(wrap(Brightness.light, build));
    await tester.pumpAndSettle();
    expect(cardColor(tester, TodayPracticeSummary), HomePalette.light.surface);

    await tester.pumpWidget(wrap(Brightness.dark, build));
    await tester.pumpAndSettle();
    expect(cardColor(tester, TodayPracticeSummary), HomePalette.dark.surface);
  });
}
