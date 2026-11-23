// 레벨 보따리와 레벨별 하루 상한(5차 566, 사용자 요청).
//
// 보따리는 표로 고정돼 있어 평생 받는 총량이 정해져 있다. 하루 상한만
// 레벨로 늘리고 주·달 상한은 그대로 둬서 한 달 총량은 움직이지 않는다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/parrot_level.dart';
import 'package:parrokit/core/content/practice_reward.dart';
import 'package:parrokit/core/content/speaking_xp.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('하루 상한', () {
    test('레벨이 오르면 하루 상한만 늘어난다', () {
      expect(rewardDailyCapFor(1), rewardDailyCap);
      expect(rewardDailyCapFor(5), 380);
      expect(rewardDailyCapFor(16), 600);
    });

    test('600에서 멈춘다', () {
      expect(rewardDailyCapFor(30), 600);
      expect(rewardDailyCapFor(100), 600);
    });

    // 한 달 총량이 움직이면 패롯 1 = 크래커 1,000이라 그대로 돈이 된다.
    test('주·달 상한은 그대로다', () {
      expect(rewardWeeklyCap, 1500);
      expect(rewardMonthlyCap, 5000);
    });

    test('하루 상한을 올려도 주 상한이 먼저 막는다', () {
      const ledger = RewardLedger(day: 0, week: 1500, month: 2000);
      expect(ledger.allowanceOf(dailyCap: 600), 0);
    });
  });

  group('보따리 표', () {
    test('오른 구간의 것만 더한다', () {
      expect(levelRewardBetween(1, 4), 0);
      expect(levelRewardBetween(4, 5), 300);
      expect(levelRewardBetween(1, 10), 1600); // 5·7·10
      expect(levelRewardBetween(10, 10), 0);
    });

    test('평생 총량이 표에 묶여 있다', () {
      expect(levelRewardBetween(0, 100), 4900);
    });

    test('다음 보따리 레벨을 알려 준다', () {
      expect(nextRewardLevel(1), 5);
      expect(nextRewardLevel(5), 7);
      expect(nextRewardLevel(20), isNull);
    });
  });

  group('받은 데까지 적어 두기', () {
    // 소급해 주면 이미 Lv.20인 사람이 앱을 켜는 순간 표 전체를 받는다.
    test('처음에는 지금 레벨까지 이미 받은 것으로 본다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.parrot.xp.v2.tester': cumulativeXpFor(12),
      });

      expect(await ParrotLevelRewards.claimedLevel('tester'), 12);
      expect(await ParrotLevelRewards.pending('tester'), 0);
    });

    test('레벨이 오르면 그만큼만 밀려 있다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.parrot.xp.v2.tester': cumulativeXpFor(4),
      });
      expect(await ParrotLevelRewards.claimedLevel('tester'), 4);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('parrokit.parrot.xp.v2.tester', cumulativeXpFor(7));

      expect(await ParrotLevelRewards.pending('tester'), 800); // Lv.5 + Lv.7
    });

    test('받았다고 적으면 다시 밀리지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.parrot.xp.v2.tester': cumulativeXpFor(7),
        'parrokit.parrot.level_rewards.v1.tester': 4,
      });

      expect(await ParrotLevelRewards.pending('tester'), 800);
      await ParrotLevelRewards.markClaimed('tester', 7);
      expect(await ParrotLevelRewards.pending('tester'), 0);
    });
  });
}
