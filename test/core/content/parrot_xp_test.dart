// 새 경험치 곡선과 옛 값 옮기기(5차 566, 사용자 요청).
//
// 레벨이 내려가는 것이 이 작업에서 유일하게 되돌릴 수 없는 사고다.
// 화면에 보이던 레벨이 그대로 유지되는지 표로 박아 둔다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/parrot_xp_day.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/content/speaking_xp.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('곡선', () {
    test('첫 레벨은 15 XP, 한 칸씩 10씩 늘어난다', () {
      expect(xpForLevel(1), 15);
      expect(xpForLevel(2), 25);
      expect(xpForLevel(19), 195);
    });

    test('누적 XP 표', () {
      expect(cumulativeXpFor(1), 0);
      expect(cumulativeXpFor(2), 15);
      expect(cumulativeXpFor(5), 120);
      expect(cumulativeXpFor(10), 495);
      expect(cumulativeXpFor(20), 1995);
    });

    test('누적 XP로 레벨을 되찾는다', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(14), 1);
      expect(levelForXp(15), 2);
      expect(levelForXp(494), 9);
      expect(levelForXp(495), 10);
      expect(levelForXp(1995), 20);
    });

    test('이번 단계에서 쌓은 몫', () {
      expect(xpInLevelOf(0), 0);
      expect(xpInLevelOf(14), 14);
      expect(xpInLevelOf(15), 0);
      expect(xpInLevelOf(275), 35);
    });

    test('음수는 Lv.1로 본다', () {
      expect(levelForXp(-5), 1);
      expect(xpInLevelOf(-5), 0);
    });
  });

  // 옛 값을 그대로 새 곡선에 넣으면 레벨이 내려간다(79.9는 옛 Lv.8,
  // 새 곡선에서는 Lv.5다). 보이던 레벨과 막대 비율을 옮긴다.
  group('옛 XP 옮기기', () {
    void check(double oldXp, int level, int inLevel) {
      final moved = migrateXp(oldXp);
      expect(levelForXp(moved), level, reason: '옛 $oldXp');
      expect(xpInLevelOf(moved), inLevel, reason: '옛 $oldXp');
    }

    test('보이던 레벨과 막대가 그대로다', () {
      check(7.9, 1, 11); // Lv.1 · 7.9/10 → Lv.1 · 11/15
      check(20, 3, 0); // Lv.3 · 0/10 → Lv.3 · 0/35
      check(75, 8, 42); // Lv.8 · 5/10 → Lv.8 · 42/85
      check(199, 20, 184); // Lv.20 · 9/10 → Lv.20 · 184/205
    });

    test('옮기는 것만으로 레벨이 오르지도 않는다', () {
      for (var tenth = 0; tenth < 3000; tenth++) {
        final old = tenth / 10;
        expect(levelForXp(migrateXp(old)), speakingLevel(old), reason: '옛 $old');
      }
    });

    test('레벨은 절대 내려가지 않는다', () {
      for (var tenth = 0; tenth < 3000; tenth++) {
        final old = tenth / 10;
        expect(levelForXp(migrateXp(old)), greaterThanOrEqualTo(speakingLevel(old)),
            reason: '옛 $old');
      }
    });

    test('처음 읽을 때 한 번만 옮기고 그 값을 쓴다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.speaking.xp.v1.tester': 75.0,
      });

      expect(await loadParrotXp('tester'), 357);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('parrokit.parrot.xp.v2.tester'), 357);
      // 옛 자리는 건드리지 않는다. practice_calendar가 그 값을 '예전 누적
      // 문장 수'로도 읽는다.
      expect(prefs.getDouble('parrokit.speaking.xp.v1.tester'), 75.0);

      await addParrotXp('tester', 2);
      expect(await loadParrotXp('tester'), 359);
    });
  });

  // 성취 XP를 주는 곳이 여럿이다(홈 무대·대시보드·문장 상세·단어 복습).
  // 머리의 막대는 홈 무대가 제 상태로 들고 있어서, 다른 곳에서 준 XP는
  // 탭을 나갔다 와야 보였다. 목표를 채워 받는 +6이 그랬다(5차 566).
  group('XP가 바뀌면 알린다', () {
    test('더할 때마다 오른다', () async {
      final before = parrotXpRevision.value;

      await addParrotXp('tester', 2);

      expect(parrotXpRevision.value, before + 1);
    });

    test('줄 것이 없으면 알리지 않는다', () async {
      final before = parrotXpRevision.value;

      await addParrotXp('tester', 0);

      expect(parrotXpRevision.value, before);
    });

    test('머리의 막대가 그 알림을 듣는다', () {
      final stage = File(
        'lib/features/home/dashboard/presentation/stage_preview_screen.dart',
      ).readAsStringSync();
      expect(stage, contains('parrotXpRevision.addListener'));
      expect(stage, contains('parrotXpRevision.removeListener'));
    });
  });

  group('성취는 하루 한 번', () {
    test('첫 연습은 하루에 한 번만 준다', () async {
      expect(await markFirstPracticeToday('tester'), isTrue);
      expect(await markFirstPracticeToday('tester'), isFalse);
    });

    test('날이 바뀌면 다시 준다', () async {
      final today = DateTime(2026, 11, 23, 12);
      final tomorrow = DateTime(2026, 11, 24, 12);
      expect(await markFirstPracticeToday('tester', now: today), isTrue);
      expect(await markFirstPracticeToday('tester', now: today), isFalse);
      expect(await markFirstPracticeToday('tester', now: tomorrow), isTrue);
    });

    test('성취마다 따로 센다', () async {
      expect(await markFirstPracticeToday('tester'), isTrue);
      expect(await markDailyGoalToday('tester'), isTrue);
      expect(await markFirstWordsToday('tester'), isTrue);
      expect(await markDailyGoalToday('tester'), isFalse);
    });
  });

  // 복습 큐가 열 개보다 짧은 날이 보통이다(간격 반복). 열 개를 채워야
  // 준다고 두면 다 풀어도 영영 못 받는다(5차 566).
  group('단어 복습 묶음', () {
    test('큐가 짧으면 그 수만큼만 채우면 된다', () {
      final source = File(
        'lib/features/collection/shell/presentation/widgets/'
        'word_collection_preview.dart',
      ).readAsStringSync();
      expect(source, contains('wordReviewXpCount < widget.words.length'));
      expect(source, contains('solvedCount + 1 == target'));
    });

    test('묶음 크기는 열 개다', () {
      expect(wordReviewXpCount, 10);
      expect(firstWordsXp, 3);
    });
  });

  group('문장 하루 몫', () {
    const id = 's1';

    test('한 문장은 하루 6점까지만 쌓인다', () async {
      final day = DateTime(2026, 11, 23, 9);
      for (var i = 0; i < 5; i++) {
        await SentenceActivityStore.incrementPractice('tester', id,
            score: 1.0, now: day);
      }
      final activity = await SentenceActivityStore.load('tester', id);
      expect(activity.practiceScore, sentenceDailyPointCap);
      // 연습 횟수는 그대로 센다. 크래커와 하루 목표를 막지 않는다.
      expect(activity.practiceCount, 5);
    });

    test('날이 바뀌면 다시 쌓인다', () async {
      final day = DateTime(2026, 11, 23, 9);
      final next = DateTime(2026, 11, 24, 9);
      for (var i = 0; i < 3; i++) {
        await SentenceActivityStore.incrementPractice('tester', id,
            score: 1.0, now: day);
      }
      await SentenceActivityStore.incrementPractice('tester', id,
          score: 1.0, now: next);
      expect((await SentenceActivityStore.load('tester', id)).practiceScore,
          sentenceDailyPointCap + 3);
    });

    // 들은 횟수와 친밀도 점수는 다른 수다(5차 566). 기록 화면의
    // '듣기 N회'와 '듣기 횟수 기록' 스위치는 횟수를 가리킨다.
    test('듣기 점수는 하루 2점까지, 횟수는 그대로 센다', () async {
      final day = DateTime(2026, 11, 23, 9);
      for (var i = 0; i < 10; i++) {
        await SentenceActivityStore.incrementListen('tester', id, now: day);
      }
      final activity = await SentenceActivityStore.load('tester', id);
      expect(activity.listenCount, 10);
      expect(activity.listenScore, sentenceDailyListenCap);
      expect(affinityOf(activity).points, sentenceDailyListenCap);
    });

    test('예전 기록은 횟수가 곧 점수였다', () {
      const old = SentenceActivity(listenCount: 7);
      expect(old.listenPoints, isNull);
      expect(old.listenScore, 7);
      expect(affinityOf(old).points, 7);
    });

    test('몫을 다 쓰면 알려 준다', () async {
      final day = DateTime(2026, 11, 23, 9);
      for (var i = 0; i < 2; i++) {
        await SentenceActivityStore.incrementPractice('tester', id,
            score: 1.0, now: day);
      }
      final result = await SentenceActivityStore.incrementPractice(
          'tester', id,
          score: 1.0, now: day);
      expect(result.gained, 0);
      expect(result.dayFull, isTrue);
    });
  });

  group('단계 상승 XP', () {
    test('오른 단계만큼만 준다', () {
      expect(affinityXpBetween(1, 2), 2);
      expect(affinityXpBetween(1, 3), 6);
      expect(affinityXpBetween(4, 5), 14);
      expect(affinityXpBetween(1, 7), 78);
      expect(affinityXpBetween(5, 5), 0);
    });

    test('같은 단계를 두 번 주지 않는다', () async {
      const id = 's2';
      final day = DateTime(2026, 11, 23, 9);
      // 3점이면 Lv.2다. 그 뒤로는 같은 단계에 XP를 또 주지 않는다.
      final first = await SentenceActivityStore.incrementPractice('tester', id,
          score: 1.0, now: day);
      expect(first.leveledTo, 2);
      expect(first.xp, 2);
      final second = await SentenceActivityStore.incrementPractice('tester', id,
          score: 1.0, now: day);
      expect(second.leveledTo, isNull);
      expect(second.xp, 0);
    });

    test('예전 기록은 이미 올라 있던 단계만큼 주지 않는다', () async {
      // topLevel이 없는 예전 활동을 그대로 두고 한 번 연습한다.
      const id = 's3';
      SharedPreferences.setMockInitialValues({
        'parrokit.sentence_activity.v1.tester':
            '{"$id":{"practiceCount":20,"practicePoints":40,"listenCount":0}}',
      });
      final day = DateTime(2026, 11, 23, 9);
      final result = await SentenceActivityStore.incrementPractice(
          'tester', id,
          score: 1.0, now: day);
      // 40점에서 43점이면 아직 Lv.4다. 올라간 단계가 없으니 XP도 없다.
      expect(result.leveledTo, isNull);
      expect(result.xp, 0);
    });
  });

  group('복습할 때', () {
    test('연습한 적 없으면 아니다', () {
      expect(needsReview(const SentenceActivity()), isFalse);
    });

    test('단계가 높을수록 주기가 길다', () {
      final now = DateTime(2026, 11, 23);
      final familiar = SentenceActivity(
        practicePoints: 3,
        lastPracticedAt: now.subtract(const Duration(days: 4)),
      );
      final fluent = SentenceActivity(
        practicePoints: 50,
        lastPracticedAt: now.subtract(const Duration(days: 4)),
      );
      expect(needsReview(familiar, now: now), isTrue, reason: 'Lv.2는 3일');
      expect(needsReview(fluent, now: now), isFalse, reason: 'Lv.5는 30일');
    });
  });
}
