import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/study_garden_preview.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/today_practice_summary.dart';

void main() {
  // MaterialApp은 테마 변경을 애니메이션으로 적용하므로(AnimatedTheme),
  // 밝기를 바꾼 뒤에는 애니메이션이 끝날 때까지 기다려야 새 색이 반영된다.
  Widget wrap(ThemeData theme, Widget Function() build) => MaterialApp(
        theme: theme,
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

  test('앱 테마가 색 토큰을 라이트·다크 모두 등록한다', () {
    expect(AppTheme.light.extension<AppTokens>(), AppTokens.light);
    expect(AppTheme.light.extension<HomeTokens>(), HomeTokens.light);
    expect(AppTheme.dark.extension<AppTokens>(), AppTokens.dark);
    expect(AppTheme.dark.extension<HomeTokens>(), HomeTokens.dark);
  });

  test('토큰을 등록하지 않은 테마에서는 밝기에 맞는 기본값으로 떨어진다', () {
    // of(context)가 null을 돌려주지 않는지만 본다. 화면이 테마를 통째로
    // 바꿔도 색이 비지 않아야 한다.
    expect(AppTokens.light.isDark, isFalse);
    expect(AppTokens.dark.isDark, isTrue);
  });

  testWidgets('학습 캘린더 카드는 테마 밝기에 따라 배경색이 바뀐다', (tester) async {
    StudyGardenPreview build() => const StudyGardenPreview(
          practiceCounts: {},
          practiceGoals: {},
          dailyGoal: 5,
          totalPracticed: 0,
        );

    await tester.pumpWidget(wrap(AppTheme.light, build));
    await tester.pumpAndSettle();
    expect(cardColor(tester, StudyGardenPreview), HomeTokens.light.surface);

    await tester.pumpWidget(wrap(AppTheme.dark, build));
    await tester.pumpAndSettle();
    expect(cardColor(tester, StudyGardenPreview), HomeTokens.dark.surface);
  });

  testWidgets('오늘 연습 카드도 다크 모드에서 어두운 배경을 쓴다', (tester) async {
    TodayPracticeSummary build() => TodayPracticeSummary(
          completed: 1,
          goal: 5,
          total: 10,
          onEditGoal: () {},
        );

    await tester.pumpWidget(wrap(AppTheme.light, build));
    await tester.pumpAndSettle();
    expect(cardColor(tester, TodayPracticeSummary), HomeTokens.light.surface);

    await tester.pumpWidget(wrap(AppTheme.dark, build));
    await tester.pumpAndSettle();
    expect(cardColor(tester, TodayPracticeSummary), HomeTokens.dark.surface);
  });
}
