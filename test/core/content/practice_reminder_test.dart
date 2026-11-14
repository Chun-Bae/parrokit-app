import 'dart:math';

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

    test('문장 고르는 방식도 그대로 남는다', () async {
      expect((await PracticeReminder.load()).pick, ReminderPick.inOrder);
      await PracticeReminder.save(const PracticeReminderSettings(
          enabled: true, hour: 7, minute: 5, pick: ReminderPick.random));
      expect((await PracticeReminder.load()).pick, ReminderPick.random);
    });

    test('모르는 방식이 적혀 있으면 순서대로로 읽는다', () {
      expect(reminderPickFromKey(null), ReminderPick.inOrder);
      expect(reminderPickFromKey('없는값'), ReminderPick.inOrder);
      expect(reminderPickFromKey('least_practiced'),
          ReminderPick.leastPracticed);
    });
  });

  group('간격으로 받기', () {
    test('간격을 주면 시작 시각부터 끝 시각까지 그 간격마다', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 8), 9, 0,
          days: 1, intervalMinutes: 180, endHour: 18);
      expect(times, [
        DateTime(2026, 11, 14, 9),
        DateTime(2026, 11, 14, 12),
        DateTime(2026, 11, 14, 15),
        DateTime(2026, 11, 14, 18),
      ]);
    });

    test('끝 시각에 딱 떨어지지 않으면 넘기지 않는다', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 8), 9, 0,
          days: 1, intervalMinutes: 300, endHour: 18);
      expect(times, [DateTime(2026, 11, 14, 9), DateTime(2026, 11, 14, 14)]);
    });

    test('오늘 이미 지난 칸은 빼고 다음 칸부터', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 13, 30), 9, 0,
          days: 2, intervalMinutes: 120, endHour: 17);
      expect(times.first, DateTime(2026, 11, 14, 15));
      expect(times[1], DateTime(2026, 11, 14, 17));
      expect(times[2], DateTime(2026, 11, 15, 9));
    });

    test('너무 가까운 칸(10초 안쪽)도 건너뛴다', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 14, 59, 55), 9, 0,
          days: 1, intervalMinutes: 120, endHour: 17);
      expect(times.first, DateTime(2026, 11, 14, 17));
    });

    test('기기가 들고 있을 수 있는 수에서 끊는다', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 0), 9, 0,
          days: 14, intervalMinutes: 30, endHour: 22, maxCount: 5);
      expect(times.length, 5);
      expect(times.last, DateTime(2026, 11, 14, 11));
    });

    test('시작이 끝보다 늦으면 그날은 한 번만', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 8), 23, 0,
          days: 2, intervalMinutes: 60, endHour: 22);
      expect(times, [DateTime(2026, 11, 14, 23), DateTime(2026, 11, 15, 23)]);
    });

    test('가장 짧은 간격은 1분이고 그대로 예약한다', () {
      expect(reminderIntervalChoices.where((m) => m > 0).reduce(min), 1);
      final times = reminderTimes(DateTime(2026, 11, 14, 8, 59), 9, 0,
          days: 1, intervalMinutes: 1, endHour: 10, maxCount: 3);
      expect(times, [
        DateTime(2026, 11, 14, 9),
        DateTime(2026, 11, 14, 9, 1),
        DateTime(2026, 11, 14, 9, 2),
      ]);
    });

    test('그만 받을 시각은 분까지 본다', () async {
      final times = reminderTimes(DateTime(2026, 11, 14, 8), 9, 0,
          days: 1, intervalMinutes: 60, endHour: 11, endMinute: 30);
      expect(times.last, DateTime(2026, 11, 14, 11));

      await PracticeReminder.save(const PracticeReminderSettings(
          enabled: true,
          hour: 9,
          minute: 0,
          intervalMinutes: 60,
          endHour: 21,
          endMinute: 30));
      final saved = await PracticeReminder.load();
      expect(saved.endMinute, 30);
      expect(saved.endLabel, '오후 9:30');
    });

    test('간격이 0이면 예전처럼 하루 한 번', () {
      final times = reminderTimes(DateTime(2026, 11, 14, 8), 9, 0,
          days: 2, intervalMinutes: 0);
      expect(times, [DateTime(2026, 11, 14, 9), DateTime(2026, 11, 15, 9)]);
    });

    test('간격과 끝 시각을 저장하고 다시 읽는다', () async {
      expect((await PracticeReminder.load()).intervalMinutes, 0);
      await PracticeReminder.save(const PracticeReminderSettings(
          enabled: true,
          hour: 9,
          minute: 0,
          intervalMinutes: 120,
          endHour: 18));
      final s = await PracticeReminder.load();
      expect(s.intervalMinutes, 120);
      expect(s.endHour, 18);
      expect(s.endMinute, 0);
      expect(s.repeats, isTrue);
    });

    test('언제 받는지 한 줄로 말한다', () {
      const once =
          PracticeReminderSettings(enabled: true, hour: 20, minute: 0);
      expect(once.whenLabel, '오후 8:00에');
      expect(
          once
              .copyWith(hour: 9, intervalMinutes: 120, endHour: 22)
              .whenLabel,
          '오전 9:00~오후 10:00, 2시간마다');
      expect(reminderTimeLabel(22, 0), '오후 10:00');
      expect(reminderTimeLabel(0, 5), '오전 12:05');
      expect(reminderIntervalLabel(0), '하루 한 번');
      expect(reminderIntervalLabel(1), '1분마다');
      expect(reminderIntervalLabel(30), '30분마다');
      expect(reminderIntervalLabel(90), '1시간 30분마다');
    });
  });

  group('알림에 쓸 문장 고르기', () {
    ReminderCandidate c(String id) => ReminderCandidate(id: id, text: id);
    final all = [c('a'), c('b'), c('c')];

    test('고른 것이 없으면 전부 쓴다', () {
      expect(chosenReminderCandidates(all, const {}), all);
    });

    test('고른 문장만 쓴다', () {
      expect(
          chosenReminderCandidates(all, {'a', 'c'}).map((e) => e.id).toList(),
          ['a', 'c']);
    });

    test('고른 문장이 모두 사라졌으면 전부 쓴다(알림이 멈추지 않게)', () {
      expect(chosenReminderCandidates(all, {'지워진-문장'}), all);
    });

    test('고른 문장 id를 저장하고 다시 읽는다', () async {
      expect(await PracticeReminder.loadChosen(), isEmpty);
      await PracticeReminder.saveChosen({'a', 'b'});
      expect(await PracticeReminder.loadChosen(), {'a', 'b'});
    });
  });

  group('문장 고르는 방식', () {
    ReminderCandidate c(String text, {int count = 0, DateTime? at}) =>
        ReminderCandidate(text: text, practiceCount: count, lastPracticedAt: at);

    final day = DateTime(2026, 11, 1);
    final candidates = [
      c('much', count: 5, at: day),
      c('never'),
      c('once-old', count: 1, at: day),
      c('once-new', count: 1, at: day.add(const Duration(days: 3))),
    ];

    test('순서대로는 저장한 차례 그대로', () {
      expect(orderReminderLines(candidates, ReminderPick.inOrder),
          ['much', 'never', 'once-old', 'once-new']);
    });

    test('덜 익숙한 순은 횟수 적은 순, 같으면 오래 안 한 순', () {
      expect(orderReminderLines(candidates, ReminderPick.leastPracticed),
          ['never', 'once-old', 'once-new', 'much']);
    });

    test('랜덤은 차례만 바꾸고 문장을 빠뜨리지 않는다', () {
      final shuffled =
          orderReminderLines(candidates, ReminderPick.random, random: Random(1));
      expect(shuffled..sort(), ['much', 'never', 'once-new', 'once-old']);
    });

    test('어느 방식이든 빈 문장은 빼고 앞뒤 공백을 지운다', () {
      for (final pick in ReminderPick.values) {
        expect(orderReminderLines([c('  a  '), c('   ')], pick), ['a'],
            reason: pick.key);
        expect(orderReminderLines(const [], pick), isEmpty, reason: pick.key);
      }
    });

    test('정한 차례대로 날짜 수만큼 돌려 쓴다', () {
      final ordered =
          orderReminderLines(candidates, ReminderPick.leastPracticed);
      expect(pickReminderLines(ordered, 6),
          ['never', 'once-old', 'once-new', 'much', 'never', 'once-old']);
    });
  });
}
