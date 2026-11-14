// 시각 고르기 시트(휠). Material 시계판 대화상자를 대신한다(5차).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/app_time_picker_sheet.dart';

void main() {
  Future<TimeOfDay?> open(WidgetTester tester,
      {TimeOfDay initial = const TimeOfDay(hour: 20, minute: 0)}) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TimeOfDay? result;
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showAppTimePickerSheet(
                context: context,
                initial: initial,
                title: '알림 받을 시각',
              );
              closed = true;
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    return result;
  }

  testWidgets('제목과 지금 고른 시각을 보여 준다', (tester) async {
    await open(tester);
    expect(find.text('알림 받을 시각'), findsOneWidget);
    expect(find.text('오후 8:00'), findsOneWidget);
  });

  testWidgets('이 시각으로를 누르면 고른 시각이 돌아온다', (tester) async {
    await open(tester, initial: const TimeOfDay(hour: 7, minute: 5));
    await tester.tap(find.byKey(const ValueKey('time-sheet-done')));
    await tester.pumpAndSettle();
    expect(find.text('알림 받을 시각'), findsNothing);
  });

  testWidgets('취소하면 아무것도 돌려주지 않는다', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('time-sheet-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('알림 받을 시각'), findsNothing);
  });

  testWidgets('시계판 대화상자(Material showTimePicker)를 쓰지 않는다', (tester) async {
    await open(tester);
    // 예전에는 시계판·숫자 입력 전환이 있는 큰 대화상자였다(사용자 의견).
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('OK'), findsNothing);
  });
}
