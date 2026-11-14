// 홈 '오늘' 한 줄(5차). 목표가 무엇을 세는지 적는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/today_start_bar.dart';

Widget _app({required int completed, required int goal}) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: TodayStartBar(
          completed: completed,
          goal: goal,
          onStart: () {},
        ),
      ),
    );

void main() {
  testWidgets('목표를 못 채웠으면 무엇을 세는지 적는다', (tester) async {
    await tester.pumpWidget(_app(completed: 2, goal: 5));
    // 옆의 '학습하기'(영상 학습)는 이 수를 올리지 않는다.
    expect(find.text('오늘 목표 · 따라 말하기'), findsOneWidget);
    // 숫자와 단위는 한 Text.rich라 합쳐진 글로 본다.
    expect(find.text('2 / 5 문장', findRichText: true), findsOneWidget);
  });

  testWidgets('다 채우면 완료라고만 적는다', (tester) async {
    await tester.pumpWidget(_app(completed: 5, goal: 5));
    expect(find.text('오늘 목표 완료'), findsOneWidget);
  });

  testWidgets('목표가 0이어도 나누기로 깨지지 않는다', (tester) async {
    await tester.pumpWidget(_app(completed: 0, goal: 0));
    expect(find.text('0 / 1 문장', findRichText: true), findsOneWidget);
  });
}
