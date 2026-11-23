import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'practice_reward.dart';

/// 받은 크래커를 기기에 적어 두고 상한을 지킨다.
///
/// **더는 앱이 쓰지 않는다**(5차 568). 뽑기와 상한은 서버
/// (functions/src/practiceReward.ts)가 쥐고, 앱은 RewardService로 청한다.
/// 기기에만 두면 앱을 지울 때 상한이 풀리고, 마음먹으면 고쳐 쓸 수 있었다.
///
/// 지우지 않고 둔 것은 옛 기기에 남은 장부를 읽을 일이 생길 수 있어서다.
/// 쓸 데가 없다고 확인되면 테스트와 함께 지운다.
class PracticeRewardStore {
  PracticeRewardStore._();

  static String key(String accountId) =>
      'parrokit.practice_reward.ledger.v1.$accountId';

  static Future<RewardLedger> load(String accountId,
      {DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key(accountId));
      final stored = raw == null
          ? const RewardLedger()
          : RewardLedger.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
      return stored.rolledOver(now ?? DateTime.now());
    } catch (_) {
      return const RewardLedger().rolledOver(now ?? DateTime.now());
    }
  }

  static Future<void> save(String accountId, RewardLedger ledger) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key(accountId), jsonEncode(ledger.toJson()));
    } catch (_) {
      // 적어 두지 못하면 상한이 느슨해질 뿐이다. 연습을 막지는 않는다.
    }
  }

  /// 줄 크래커를 뽑는다. 장부에는 아직 적지 않는다.
  ///
  /// 상한에 걸리면 남은 만큼으로 깎는다. 0이면 [RewardGrant.isEmpty]다.
  /// 잔액에 더하는 데 실패했는데 장부에만 적히면 받지도 않고 상한이 깎인다.
  /// 그래서 뽑기와 적기를 나눴다([confirm]).
  /// [dailyCap]을 주면 하루 상한만 그 값으로 본다. 레벨이 오르면 하루
  /// 상한이 늘어난다(5차 566). 주·달 상한은 그대로다.
  static Future<RewardGrant> prepare(
    String accountId, {
    Random? random,
    DateTime? now,
    int? dailyCap,
  }) async {
    final ledger = await load(accountId, now: now);
    final rolled = rollRewardCrackers(random);
    final allowance = ledger.allowanceOf(dailyCap: dailyCap);
    final tightest = ledger.tightestOf(dailyCap: dailyCap);
    if (allowance <= 0) {
      return RewardGrant(crackers: 0, rolled: rolled, cap: tightest);
    }
    if (rolled <= allowance) {
      return RewardGrant(crackers: rolled, rolled: rolled);
    }
    return RewardGrant(crackers: allowance, rolled: rolled, cap: tightest);
  }

  /// 실제로 준 크래커를 장부에 적는다. 잔액에 더한 뒤에 부른다.
  static Future<void> confirm(
    String accountId,
    RewardGrant grant, {
    DateTime? now,
  }) async {
    if (grant.isEmpty) return;
    final ledger = await load(accountId, now: now);
    await save(accountId, ledger.plus(grant.crackers));
  }

  /// 뽑아서 바로 장부에 적는다. 잔액을 건드리지 않는 자리에서 쓴다.
  static Future<RewardGrant> grant(
    String accountId, {
    Random? random,
    DateTime? now,
  }) async {
    final grant = await prepare(accountId, random: random, now: now);
    await confirm(accountId, grant, now: now);
    return grant;
  }
}
