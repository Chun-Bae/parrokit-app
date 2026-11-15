// 홈 '학습 캘린더'에 적는 곳(5차).
//
// 전에는 홈 무대 화면이 혼자 들고 있어, 보관함 문장 창에서 따라 말하면
// 캘린더에 안 쌓였다. 바로 위 '내 문장 기록'과 어긋나 보였다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/practice_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('아무것도 안 했으면 비어 있다', () async {
    final data = await PracticeCalendar.load('me');

    expect(data.counts, isEmpty);
    expect(data.total, 0);
    expect(data.dailyGoal, PracticeCalendar.defaultDailyGoal);
  });

  test('한 문장을 따라 말하면 그날 자리에 쌓인다', () async {
    final day = DateTime(2026, 11, 16);

    final after = await PracticeCalendar.recordOne('me', now: day);

    expect(after.counts[PracticeCalendar.dateKey(day)], 1);
    expect(after.total, 1);
    // 그날의 목표도 함께 적어 둔다(나중에 목표를 바꿔도 지난 날은 그대로).
    expect(after.goals[PracticeCalendar.dateKey(day)],
        PracticeCalendar.defaultDailyGoal);
  });

  test('어느 화면에서 했든 같은 자리에 쌓인다', () async {
    final day = DateTime(2026, 11, 16);

    await PracticeCalendar.recordOne('me', now: day); // 홈 무대
    await PracticeCalendar.recordOne('me', now: day); // 보관함 문장 창
    final data = await PracticeCalendar.load('me');

    expect(data.counts[PracticeCalendar.dateKey(day)], 2);
    expect(data.total, 2);
  });

  test('계정마다 따로 센다', () async {
    final day = DateTime(2026, 11, 16);

    await PracticeCalendar.recordOne('나', now: day);
    final other = await PracticeCalendar.load('남');

    expect(other.counts, isEmpty);
    expect(other.total, 0);
  });

  test('목표를 바꾼 뒤에도 지난 날은 그때 목표로 본다', () async {
    SharedPreferences.setMockInitialValues({
      PracticeCalendar.goalKey('me'): 3,
    });
    final yesterday = DateTime(2026, 11, 15);
    await PracticeCalendar.recordOne('me', now: yesterday);

    SharedPreferences.setMockInitialValues({
      PracticeCalendar.goalKey('me'): 10,
      PracticeCalendar.goalsKey('me'):
          jsonEncode({PracticeCalendar.dateKey(yesterday): 3}),
    });
    final today = DateTime(2026, 11, 16);
    final after = await PracticeCalendar.recordOne('me', now: today);

    expect(after.goals[PracticeCalendar.dateKey(yesterday)], 3);
    expect(after.goals[PracticeCalendar.dateKey(today)], 10);
  });

  test('예전 기록을 그대로 읽는다', () async {
    // 저장 자리와 모양을 바꾸지 않았다.
    SharedPreferences.setMockInitialValues({
      PracticeCalendar.historyKey('me'): jsonEncode({'2026-11-01': 4}),
      PracticeCalendar.totalKey('me'): 4,
    });

    final data = await PracticeCalendar.load('me');

    expect(data.counts['2026-11-01'], 4);
    expect(data.total, 4);
  });

  test('깨진 기록은 버리고 다시 쌓는다', () async {
    SharedPreferences.setMockInitialValues({
      PracticeCalendar.historyKey('me'): '깨진 글',
    });

    final data = await PracticeCalendar.load('me');

    expect(data.counts, isEmpty);
  });
}
