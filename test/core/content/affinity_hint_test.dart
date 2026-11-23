// 막대 아래 안내가 오늘 남은 몫을 말하는지(5차 566).
//
// 듣기 몫을 다 쓴 뒤에도 '들으면 1점'이라고 적혀 있으면, 열 번을 더
// 들어도 막대가 안 움직이니 고장난 것으로 보인다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/shared/widgets/sentence_affinity_bar.dart';

void main() {
  final day = DateTime(2026, 11, 23, 9);
  final today = sentenceDayKey(day);

  test('기록이 없으면 두 가지 길을 다 적는다', () {
    const activity = SentenceActivity(practicePoints: 3);
    expect(affinityHint(affinityOf(activity)),
        contains('들으면 1점, 따라 말하면 1~3점'));
  });

  test('듣기 몫만 다 썼으면 따라 말하기를 가리킨다', () {
    final activity = SentenceActivity(
      practicePoints: 3,
      dayKey: today,
      dayPoints: sentenceDailyListenCap,
      listenDayPoints: sentenceDailyListenCap,
    );
    final hint = affinityHint(affinityOf(activity), activity: activity, now: day);
    expect(hint, contains('오늘 듣기 몫은 다 썼어요'));
    expect(hint, isNot(contains('들으면 1점')));
  });

  test('문장 몫을 다 썼으면 내일 다시 쌓인다고 말한다', () {
    final activity = SentenceActivity(
      practicePoints: 3,
      dayKey: today,
      dayPoints: sentenceDailyPointCap,
    );
    expect(affinityHint(affinityOf(activity), activity: activity, now: day),
        '$sentenceDayFullMessage · 내일 다시 쌓여요');
  });

  test('날이 바뀌면 다시 두 가지 길을 적는다', () {
    final activity = SentenceActivity(
      practicePoints: 3,
      dayKey: today,
      dayPoints: sentenceDailyPointCap,
      listenDayPoints: sentenceDailyListenCap,
    );
    expect(
        affinityHint(affinityOf(activity),
            activity: activity, now: day.add(const Duration(days: 1))),
        contains('들으면 1점, 따라 말하면 1~3점'));
  });

  test('최고 단계면 몫과 상관없이 최고 단계라고 한다', () {
    final activity = SentenceActivity(
      practicePoints: 1000,
      dayKey: today,
      dayPoints: sentenceDailyPointCap,
    );
    expect(affinityHint(affinityOf(activity), activity: activity, now: day),
        '최고 단계예요');
  });

  group('남은 몫', () {
    test('듣기 몫은 문장 몫보다 클 수 없다', () {
      final activity = SentenceActivity(
        dayKey: today,
        dayPoints: sentenceDailyPointCap - 1,
        listenDayPoints: 0,
      );
      expect(sentenceRoomToday(activity, now: day), 1);
      expect(sentenceListenRoomToday(activity, now: day), 1);
    });

    test('다 썼으면 0이고 음수가 되지 않는다', () {
      final activity = SentenceActivity(
        dayKey: today,
        dayPoints: sentenceDailyPointCap + 5,
        listenDayPoints: sentenceDailyListenCap + 3,
      );
      expect(sentenceRoomToday(activity, now: day), 0);
      expect(sentenceListenRoomToday(activity, now: day), 0);
    });
  });
}
