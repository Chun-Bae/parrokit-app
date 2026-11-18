// 학습 캘린더 머리의 수(5차 501).
//
// 전에는 '누적 N번'이라 처음부터 지금까지를 적었다. 그 값은 캘린더가 따로
// 들고 있는 누계라, 같은 화면 위쪽 '내 문장 기록 · 따라 말하기 N회'와
// 어긋났다(기기에서 3번 vs 6번). 기록을 쌓기 시작한 때가 달라서인데,
// 보는 사람은 같은 것을 세는 두 숫자가 왜 다른지 알 길이 없었다.
//
// 이제는 지금 펼친 달의 합을 적는다. 날짜를 눌러 더해 보면 맞는 수다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/study_garden_preview.dart';

void main() {
  final now = DateTime(2026, 11, 18);

  Future<void> pump(WidgetTester tester, Map<String, int> counts) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudyGardenPreview(
              practiceCounts: counts,
              practiceGoals: const {},
              dailyGoal: 5,
              now: now,
            ),
          ),
        ),
      ));

  testWidgets('머리에 지금 펼친 달의 합을 적는다', (tester) async {
    await pump(tester, const {
      '2026-11-15': 1,
      '2026-11-17': 1,
      '2026-11-18': 2,
      // 지난 달 것은 11월 수에 들어가지 않는다.
      '2026-10-30': 7,
    });
    expect(find.text('11월 4번'), findsOneWidget);
    // 처음부터 지금까지를 적지 않는다.
    expect(find.textContaining('누적'), findsNothing);
  });

  testWidgets('지난 달로 넘기면 그 달의 합을 적는다', (tester) async {
    await pump(tester, const {'2026-11-18': 2, '2026-10-30': 7});
    expect(find.text('11월 2번'), findsOneWidget);

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('10월 7번'), findsOneWidget);
  });

  testWidgets('그 달에 아무것도 없으면 0번', (tester) async {
    await pump(tester, const {'2026-10-30': 7});
    expect(find.text('11월 0번'), findsOneWidget);
  });
}
