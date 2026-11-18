// 연습 보상의 뽑기 표·상한·기댓값(5차 505, 사용자와 정함).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/practice_reward.dart';
import 'package:parrokit/core/content/practice_reward_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('뽑기 표', () {
    test('액수가 클수록 확률이 낮다', () {
      for (var i = 1; i < rewardTiers.length; i++) {
        expect(rewardTiers[i].crackers, greaterThan(rewardTiers[i - 1].crackers),
            reason: '액수는 오름차순이어야 읽기 쉽다');
        expect(rewardTiers[i].weight, lessThan(rewardTiers[i - 1].weight),
            reason: '${rewardTiers[i].crackers}개가 더 흔하면 안 된다');
      }
    });

    test('액수와 상한은 모두 단위의 배수다', () {
      for (final tier in rewardTiers) {
        expect(tier.crackers % rewardUnit, 0);
      }
      for (final cap in RewardCap.values) {
        expect(cap.limit % rewardUnit, 0, reason: '기댓값 계산이 이 단위로 돈다');
      }
    });

    test('무게의 합이 1,000이라 그대로 확률로 읽는다', () {
      expect(rewardTotalWeight, 1000);
    });

    test('한 번 평균은 31.8 크래커다', () {
      expect(rewardRollExpected, closeTo(31.8, 0.05));
    });

    test('뽑은 액수는 언제나 표 안에 있다', () {
      final amounts = {for (final t in rewardTiers) t.crackers};
      final random = Random(1234);
      for (var i = 0; i < 2000; i++) {
        expect(amounts, contains(rollRewardCrackers(random)));
      }
    });

    test('가장 큰 액수는 1,000이다', () {
      expect(rewardMaxCrackers, 1000);
    });
  });

  group('상한', () {
    test('상한은 하루 < 한 주 < 한 달이다', () {
      expect(rewardDailyCap, lessThan(rewardWeeklyCap));
      expect(rewardWeeklyCap, lessThan(rewardMonthlyCap));
    });

    test('하루 상한을 넘겨 주지 않는다', () async {
      final random = Random(7);
      final now = DateTime(2026, 11, 18, 9);
      var total = 0;
      for (var i = 0; i < 80; i++) {
        final grant =
            await PracticeRewardStore.grant('guest', random: random, now: now);
        total += grant.crackers;
      }
      expect(total, rewardDailyCap);
      final ledger = await PracticeRewardStore.load('guest', now: now);
      expect(ledger.day, rewardDailyCap);
    });

    test('상한을 채우면 0을 주고 어느 상한인지 말한다', () async {
      final now = DateTime(2026, 11, 18, 9);
      final random = Random(7);
      for (var i = 0; i < 80; i++) {
        await PracticeRewardStore.grant('guest', random: random, now: now);
      }
      final blocked =
          await PracticeRewardStore.grant('guest', random: random, now: now);
      expect(blocked.isEmpty, isTrue);
      expect(blocked.capped, isTrue);
      expect(blocked.cap, RewardCap.day);
      expect(practiceRewardCappedMessage(blocked.cap!), contains('오늘'));
    });

    test('날이 바뀌면 하루 칸만 0으로 돌아간다', () async {
      final day1 = DateTime(2026, 11, 18, 9);
      final random = Random(3);
      for (var i = 0; i < 80; i++) {
        await PracticeRewardStore.grant('guest', random: random, now: day1);
      }
      final next = await PracticeRewardStore.load('guest',
          now: DateTime(2026, 11, 19, 9));
      expect(next.day, 0);
      expect(next.week, rewardDailyCap, reason: '같은 주라 주 칸은 남는다');
      expect(next.month, rewardDailyCap);
    });

    test('주가 바뀌면 주 칸도 0으로 돌아간다', () async {
      // 2026-11-18은 수요일. 다음 월요일은 11-23이다.
      final random = Random(3);
      for (var i = 0; i < 80; i++) {
        await PracticeRewardStore.grant('guest',
            random: random, now: DateTime(2026, 11, 18, 9));
      }
      final next = await PracticeRewardStore.load('guest',
          now: DateTime(2026, 11, 23, 9));
      expect(next.week, 0);
      expect(next.month, rewardDailyCap, reason: '같은 달이라 달 칸은 남는다');
    });

    test('주 상한에 걸리면 하루 상한이 남아도 깎는다', () async {
      final random = Random(11);
      // 월~금 닷새로 주 상한(1,500)을 채운다.
      for (final day in [16, 17, 18, 19, 20]) {
        for (var i = 0; i < 80; i++) {
          await PracticeRewardStore.grant('guest',
              random: random, now: DateTime(2026, 11, day, 9));
        }
      }
      final saturday = DateTime(2026, 11, 21, 9);
      final ledger = await PracticeRewardStore.load('guest', now: saturday);
      expect(ledger.week, rewardWeeklyCap);
      expect(ledger.day, 0, reason: '토요일은 아직 안 받았다');
      expect(ledger.allowance, 0, reason: '하루는 비었어도 주가 막는다');
      final grant =
          await PracticeRewardStore.grant('guest', random: random, now: saturday);
      expect(grant.isEmpty, isTrue);
      expect(grant.cap, RewardCap.week);
    });

    test('계정마다 따로 센다', () async {
      final random = Random(5);
      final now = DateTime(2026, 11, 18, 9);
      for (var i = 0; i < 80; i++) {
        await PracticeRewardStore.grant('guest', random: random, now: now);
      }
      final other = await PracticeRewardStore.load('other', now: now);
      expect(other.day, 0);
      expect(other.allowance, rewardDailyCap);
    });
  });

  group('기댓값', () {
    test('하루 한 번이면 상한이 거의 안 걸려 한 번 평균에 가깝다', () {
      final f = rewardForecast(rollsPerDay: 1);
      expect(f.perPracticeDay, closeTo(30.4, 0.5));
      expect(f.perPracticeDay, lessThan(rewardRollExpected),
          reason: '1,000을 뽑아도 하루 상한이 300이라 조금 깎인다');
    });

    test('많이 연습하면 상한에서 멈춘다', () {
      final heavy = rewardForecast(rollsPerDay: 50);
      expect(heavy.perPracticeDay, closeTo(rewardDailyCap.toDouble(), 0.5));
      expect(heavy.perWeek, closeTo(rewardWeeklyCap.toDouble(), 1));
      expect(heavy.perMonth, closeTo(rewardMonthlyCap.toDouble(), 1));
      expect(heavy.parrotsPerMonth, closeTo(5, 0.01));
    });

    test('연습을 더 하면 기댓값은 줄지 않는다', () {
      var previous = 0.0;
      for (final rolls in [1, 2, 3, 5, 10, 20]) {
        final f = rewardForecast(rollsPerDay: rolls);
        expect(f.perMonth, greaterThanOrEqualTo(previous));
        previous = f.perMonth;
      }
    });

    test('연습하는 날이 적으면 한 주 기댓값도 작다', () {
      final all = rewardForecast(rollsPerDay: 3, daysPerWeek: 7);
      final some = rewardForecast(rollsPerDay: 3, daysPerWeek: 3);
      expect(some.perWeek, lessThan(all.perWeek));
      expect(some.perPracticeDay, closeTo(all.perPracticeDay, 0.01),
          reason: '연습한 날 하루치는 날수와 무관하다');
    });

    test('분포의 확률 합은 1이다', () {
      final dist = rewardDayDistribution(10);
      expect(dist.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
    });
  });

  group('글귀', () {
    test('알림 글귀는 받을 수를 미리 말하지 않는다', () {
      // 예약 알림은 며칠 전에 깔아 두므로 그날 뽑을 수를 모른다.
      for (final tier in rewardTiers) {
        if (tier.crackers == rewardMaxCrackers) continue;
        expect(practiceRewardInvite.contains('${tier.crackers}'), isFalse,
            reason: '${tier.crackers}를 약속하면 사실이 아닐 수 있다');
      }
      expect(practiceRewardInvite, contains('1,000'));
      expect(practiceRewardInvite, contains('많게는'));
    });

    test('받은 뒤에는 수를 적는다', () {
      expect(practiceRewardEarned(30), '크래커 +30');
      expect(practiceRewardEarned(1000), '크래커 +1,000');
    });

    test('쉼표는 1,000 단위로 넣는다', () {
      expect(rewardCrackerCount(10), '10');
      expect(rewardCrackerCount(300), '300');
      expect(rewardCrackerCount(1000), '1,000');
      expect(rewardCrackerCount(5000), '5,000');
    });

    test('상한 안내는 세 기간을 모두 말한다', () {
      expect(practiceRewardCapSummary, contains('300'));
      expect(practiceRewardCapSummary, contains('1,500'));
      expect(practiceRewardCapSummary, contains('5,000'));
    });
  });
}
