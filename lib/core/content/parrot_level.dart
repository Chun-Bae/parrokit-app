// 레벨이 오를 때 주는 보따리(5차 566, 사용자 요청).
//
// 전에는 레벨이 화면 글자 한 줄이었다. 올려도 열리는 것도, 받는 것도
// 없었다. 레벨마다 한 번만 주는 표를 두고, 받은 데까지를 적어 둔다.
//
// 총량이 표로 고정돼 있어 반복 획득이 불가능하다. Lv.1에서 Lv.20까지
// 평생 받는 것이 크래커 4,100이고, 패롯으로 치면 네 개어치다. 하루·주·달
// 상한과 따로 나가지만 표 바깥으로는 한 톨도 안 나간다.
//
// 패롯은 여기서 주지 않는다. 패롯은 광고·구독·결제의 통화라 앱이 직접
// 찍으면 그 셋의 이유가 함께 깎인다. 서버 함수로 옮긴 뒤에 다룬다.

import 'package:shared_preferences/shared_preferences.dart';

import 'speaking_xp.dart';

/// 레벨별 크래커 보따리. 적혀 있지 않은 레벨은 주지 않는다.
const Map<int, int> levelCrackerRewards = {
  5: 300,
  7: 500,
  10: 800,
  13: 800,
  16: 1000,
  20: 1500,
};

/// [from]보다 크고 [to] 이하인 레벨에서 받을 크래커를 모두 더한다.
int levelRewardBetween(int from, int to) {
  var sum = 0;
  for (final entry in levelCrackerRewards.entries) {
    if (entry.key > from && entry.key <= to) sum += entry.value;
  }
  return sum;
}

/// 다음 보따리가 있는 레벨. 더 없으면 null.
int? nextRewardLevel(int level) {
  final levels = levelCrackerRewards.keys.where((l) => l > level).toList()
    ..sort();
  return levels.isEmpty ? null : levels.first;
}

/// 보따리를 받은 데까지 적어 두는 자리.
class ParrotLevelRewards {
  ParrotLevelRewards._();

  static String key(String accountId) =>
      'parrokit.parrot.level_rewards.v1.$accountId';

  /// 지금까지 보따리를 받은 최고 레벨.
  ///
  /// 적혀 있지 않으면 **지금 레벨까지는 이미 받은 것으로 본다.** 소급해
  /// 주면 이미 Lv.20인 사람이 앱을 켜는 순간 표 전체를 한꺼번에 받는다.
  static Future<int> claimedLevel(String accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(key(accountId));
      if (stored != null) return stored;
      final level = levelForXp(await loadParrotXp(accountId));
      await prefs.setInt(key(accountId), level);
      return level;
    } catch (_) {
      return 0;
    }
  }

  /// [level]까지 받은 것으로 적는다.
  static Future<void> markClaimed(String accountId, int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key(accountId), level);
    } catch (_) {
      // 못 적으면 다음에 또 준다. 표가 유한해도 중복은 피하고 싶으니
      // 적기 실패는 로그 없이 넘긴다 - 연습을 막지는 않는다.
    }
  }

  /// 지금 레벨까지 밀린 보따리를 센다. 받을 것이 없으면 0.
  ///
  /// 적어 두는 것은 [markClaimed]가 따로 한다. 잔액에 더하기 전에
  /// 적으면 받지도 못하고 표에서 지워질 수 있다.
  static Future<int> pending(String accountId) async {
    final claimed = await claimedLevel(accountId);
    final level = levelForXp(await loadParrotXp(accountId));
    if (level <= claimed) return 0;
    return levelRewardBetween(claimed, level);
  }
}
