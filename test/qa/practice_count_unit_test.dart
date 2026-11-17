// 세는 것이 다르면 단위도 달라야 한다(5차 466).
//
// 홈 한 화면이 '연습한 문장 6'(가짓수), '누적 2문장'(횟수 누계),
// '따라 말하기 5회'(횟수)를 함께 보여 주면서 앞의 둘이 같은 '문장'을
// 썼다. 어느 것이 내가 연습한 문장 수인지 알 수 없었다.
//
// 같은 문장을 다섯 번 따라 말해도 목표 '5'가 채워지므로, 목표와 캘린더가
// 세는 것은 가짓수가 아니라 횟수다. 그래서 '번'으로 적는다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/practice_goal_text.dart';

void main() {
  test('목표와 캘린더 글귀는 횟수 단위를 쓴다', () {
    expect(practiceOfGoalLabel(2, 5), '2 / 5번');
    expect(practiceRemainingLabel(3), '3번 남음');
    expect(practiceTotalLabel(12), contains('12번'));
    expect(practiceCalendarTotalLabel(12), '누적 12번');
    expect(dailyGoalDialogQuestion, contains('몇 번'));
    expect(practiceCalendarHint, contains('횟수'));
  });

  test('목표와 캘린더 화면이 횟수를 문장이라 적지 않는다', () {
    const paths = [
      'lib/features/home/dashboard/presentation/widgets/today_practice_summary.dart',
      'lib/features/home/dashboard/presentation/widgets/today_start_bar.dart',
      'lib/features/home/dashboard/presentation/widgets/study_garden_preview.dart',
    ];
    for (final path in paths) {
      final src = File(path)
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(src.contains('문장'), isFalse,
          reason: '$path: 횟수를 세는 자리는 practice_goal_text의 말을 쓴다');
    }
  });
}
