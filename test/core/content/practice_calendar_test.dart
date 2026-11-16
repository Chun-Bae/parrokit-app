// 홈 '학습 캘린더'에 적는 곳(5차).
//
// 전에는 홈 무대 화면이 혼자 들고 있어, 보관함 문장 창에서 따라 말하면
// 캘린더에 안 쌓였다. 바로 위 '내 문장 기록'과 어긋나 보였다.

import 'dart:convert';
import 'dart:io';

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

  group('홈 목표와 같은 자리를 본다(5차 351)', () {
    test('홈이 적은 하루 목표를 그대로 읽는다', () async {
      // 홈의 '목표 바꾸기'가 적는 자리.
      SharedPreferences.setMockInitialValues({
        'parrokit.practice.daily_goal.v1.me': 3,
      });

      final data = await PracticeCalendar.load('me');
      expect(data.dailyGoal, 3);
    });

    test('그날 목표도 사용자가 정한 값으로 적힌다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.practice.daily_goal.v1.me': 3,
      });

      final after =
          await PracticeCalendar.recordOne('me', now: DateTime(2026, 11, 17));
      expect(after.goals['2026-11-17'], 3, reason: '전에는 늘 기본값 5로 적혔다');
    });

    test('기록하면 revision이 올라 화면이 다시 읽는다', () async {
      SharedPreferences.setMockInitialValues({});
      final before = PracticeCalendar.revision.value;

      await PracticeCalendar.recordOne('me', now: DateTime(2026, 11, 17));

      expect(PracticeCalendar.revision.value, before + 1);
    });
  });

  test('홈도 같은 곳에서 읽는다', () {
    final code = File(
            'lib/features/home/dashboard/presentation/character_dashboard_screen.dart')
        .readAsStringSync();
    expect(code, contains('PracticeCalendar.load(accountId)'));
    expect(code, contains('PracticeCalendar.revision.addListener'));
    // 홈이 따로 해독하던 코드는 없앴다.
    expect(code.contains("jsonDecode(rawHistory)"), isFalse);
  });

  group('목표 바꾸기도 한 곳에서(5차 352)', () {
    test('바꾼 목표를 홈이 읽는 자리에 적고 오늘 목표도 바꾼다', () async {
      SharedPreferences.setMockInitialValues({});

      final data = await PracticeCalendar.setDailyGoal('me', 3,
          now: DateTime(2026, 11, 17));
      expect(data.dailyGoal, 3);
      expect(data.goals['2026-11-17'], 3);

      final reloaded = await PracticeCalendar.load('me');
      expect(reloaded.dailyGoal, 3);
      expect(reloaded.goals['2026-11-17'], 3);
    });

    test('1~100 밖은 그 안으로 맞춘다', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await PracticeCalendar.setDailyGoal('me', 0)).dailyGoal, 1);
      expect((await PracticeCalendar.setDailyGoal('me', 999)).dailyGoal, 100);
    });

    test('목표를 바꿔도 revision이 올라 화면이 다시 읽는다', () async {
      SharedPreferences.setMockInitialValues({});
      final before = PracticeCalendar.revision.value;
      await PracticeCalendar.setDailyGoal('me', 4);
      expect(PracticeCalendar.revision.value, before + 1);
    });

    test('연습 기록 키를 화면이 따로 들고 있지 않다', () {
      final code = File(
              'lib/features/home/dashboard/presentation/character_dashboard_screen.dart')
          .readAsStringSync();
      expect(code.contains("'parrokit.practice."), isFalse,
          reason: '키는 practice_calendar.dart 한 곳에만 둔다(5차 351의 어긋남)');
      expect(code, contains('PracticeCalendar.setDailyGoal('));
    });
  });
}
