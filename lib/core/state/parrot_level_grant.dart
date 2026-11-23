import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/content/reward_service.dart';
import 'package:parrokit/core/content/speaking_xp.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

/// 레벨이 올라 밀린 보따리를 받아 온다(5차 566, 서버로 옮김 5차 568).
///
/// 받은 데까지와 지급을 **서버**가 한 트랜잭션에서 맡는다. 전에는 앱이
/// 기기에 적어 두고 Firestore에 직접 더했는데, 규칙이 crackers를 막으면
/// 그 길이 끊긴다.
///
/// 레벨은 앱이 보낸다. XP가 아직 기기 안에 있어 믿을 수 없지만, 보따리는
/// 표로 고정돼 있어 표 바깥(Lv.20까지 4,900)으로는 못 간다.
///
/// 화면이 직접 잔액을 건드리지 않게 여기 모은다(practice_reward_grant와
/// 같은 자리).
Future<int> grantLevelRewards(
  BuildContext context,
  String accountId, {
  RewardService? service,
}) async {
  if (!context.mounted) return 0;
  try {
    // 잔액을 들고 있는 쪽이 없으면(테스트나 Provider 밖에서 띄운 화면)
    // 조용히 지나간다. 보상이 연습을 막아서는 안 된다.
    final provider = context.read<UserProvider>();
    if (provider.currentUser == null) return 0;
  } catch (e) {
    AppLogger.d('[Level] 잔액을 들고 있는 쪽이 없어 보따리를 건너뜀: $e');
    return 0;
  }

  final level = levelForXp(await loadParrotXp(accountId));
  // 잔액은 서버가 올린다. 화면은 사용자 문서 구독으로 곧 따라온다.
  return (service ?? RewardService()).levelReward(level: level);
}
