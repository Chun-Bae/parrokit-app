// 학습 캘린더 색 눈금 설명(5차).
//
// 범례가 '적게 … 완료'였다. 첫 칸은 연습을 안 한 날 색이고 마지막 칸은 그날
// 목표를 다 채운 날이라, 무엇의 눈금인지 알기 어려웠다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/study_garden_preview.dart';

void main() {
  testWidgets('범례가 양 끝이 무엇인지 말한다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: StudyGardenPreview(
            practiceCounts: {},
            practiceGoals: {},
            dailyGoal: 5,
            totalPracticed: 0,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('안 한 날'), findsOneWidget);
    expect(find.text('목표 완료'), findsOneWidget);
    expect(find.text('적게'), findsNothing);
  });
}
