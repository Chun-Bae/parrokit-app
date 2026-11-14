import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parrokit/core/content/practice_reminder.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('알림 시각', () {
    test('오늘 그 시각이 아직 안 지났으면 오늘부터', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 9), 20, 0, days: 3);
      expect(times.first, DateTime(2026, 11, 14, 20));
      expect(times[1], DateTime(2026, 11, 15, 20));
      expect(times.length, 3);
    });

    test('이미 지났으면 내일부터', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 20, 1), 20, 0,
          days: 2);
      expect(times.first, DateTime(2026, 11, 15, 20));
      expect(times.last, DateTime(2026, 11, 16, 20));
    });

    test('딱 그 시각이면 내일부터(지금 울릴 알림은 예약하지 않는다)', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 20), 20, 0, days: 1);
      expect(times.single, DateTime(2026, 11, 15, 20));
    });

    test('너무 가까우면(10초 안쪽) 내일로 미룬다', () {
      // 9초 뒤: 예약이 끝나기도 전에 지나갈 수 있다.
      expect(
          reminderTimes(DateTime(2026, 11, 14, 19, 59, 51), 20, 0, days: 1)
              .single,
          DateTime(2026, 11, 15, 20));
      // 11초 뒤: 오늘 울린다.
      expect(
          reminderTimes(DateTime(2026, 11, 14, 19, 59, 49), 20, 0, days: 1)
              .single,
          DateTime(2026, 11, 14, 20));
    });

    test('간격은 바꿔 줄 수 있다', () {
      expect(
          reminderTimes(DateTime(2026, 11, 14, 19, 59, 51), 20, 0,
                  days: 1, minLead: Duration.zero)
              .single,
          DateTime(2026, 11, 14, 20));
    });

    test('달을 넘어가도 날짜가 이어진다', () {
      // 11월 30일 9시에는 그날 8시 30분이 지났으므로 12월 1일부터.
      final times = reminderTimes(DateTime(2026, 11, 30, 9), 8, 30, days: 3);
      expect(times[0], DateTime(2026, 12, 1, 8, 30));
      expect(times[1], DateTime(2026, 12, 2, 8, 30));
      expect(times[2], DateTime(2026, 12, 3, 8, 30));
    });
  });

  group('알림에 넣을 문장 고르기', () {
    test('문장이 적으면 돌려 쓴다', () {
      expect(pickReminderLines(['a', 'b'], 5), ['a', 'b', 'a', 'b', 'a']);
    });

    test('빈 문장은 빼고 앞뒤 공백을 없앤다', () {
      expect(pickReminderLines(['  a  ', '   ', 'b'], 3), ['a', 'b', 'a']);
    });

    test('쓸 문장이 없으면 빈 목록', () {
      expect(pickReminderLines(const [], 3), isEmpty);
      expect(pickReminderLines(['   '], 3), isEmpty);
      expect(pickReminderLines(['a'], 0), isEmpty);
    });
  });

  group('알림 글', () {
    test('문장이 있으면 그대로 본문에 쓴다', () {
      final c = reminderContent('How was your day?');
      expect(c.title, '오늘 따라 말하기');
      expect(c.body, 'How was your day?');
    });

    test('문장이 없으면 문장 없이 부른다', () {
      expect(reminderContent(null).body, isNot(contains('null')));
      expect(reminderContent('   ').body, reminderContent(null).body);
      expect(reminderContent(null).body, isNotEmpty);
    });
  });

  group('설정 저장', () {
    test('처음에는 꺼져 있고 저녁 8시다', () async {
      final s = await PracticeReminder.load();
      expect(s.enabled, isFalse);
      expect(s.hour, PracticeReminder.defaultHour);
      expect(s.minute, PracticeReminder.defaultMinute);
      expect(s.label, '오후 8:00');
    });

    test('켜고 시각을 바꾸면 그대로 남는다', () async {
      await PracticeReminder.save(const PracticeReminderSettings(
          enabled: true, hour: 7, minute: 5));
      final s = await PracticeReminder.load();
      expect(s.enabled, isTrue);
      expect(s.label, '오전 7:05');
    });

    test('자정과 정오를 12시로 보여 준다', () {
      expect(
          const PracticeReminderSettings(enabled: true, hour: 0, minute: 0)
              .label,
          '오전 12:00');
      expect(
          const PracticeReminderSettings(enabled: true, hour: 12, minute: 30)
              .label,
          '오후 12:30');
    });

    test('알림에 띄울 문장을 적어 두고 다시 읽는다', () async {
      expect(await PracticeReminder.loadLines(), isEmpty);
      await PracticeReminder.saveLines(['Hello', 'Bye']);
      expect(await PracticeReminder.loadLines(), ['Hello', 'Bye']);
    });
  });
}
