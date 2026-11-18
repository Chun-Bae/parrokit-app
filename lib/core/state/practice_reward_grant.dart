import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:parrokit/core/content/practice_reward.dart';
import 'package:parrokit/core/content/practice_reward_store.dart';
import 'package:parrokit/core/infrastructure/services/local_notification_service.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';

/// 연습 한 번에 크래커를 뽑아 주고 잔액에 더한다(5차 505).
///
/// 뽑기와 상한은 [PracticeRewardStore]가 정한다. 여기서는 잔액에 더하는 것과
/// 순서만 맡는다. 더하기에 실패하면 장부에 적지 않는다. 받지도 못했는데
/// 상한이 깎이면 안 된다.
///
/// 돌려주는 [RewardGrant]로 화면이 무엇을 보여 줄지 정한다.
/// - [RewardGrant.isEmpty]면 줄 것이 없다(상한을 다 썼거나 지급이 실패).
/// - [RewardGrant.capped]면 상한에 걸려 깎였다.
///
/// [context]는 await 전에 읽는다. 연습을 마치고 시트가 닫힐 수 있다.
Future<RewardGrant> grantPracticeReward(
  BuildContext context,
  String accountId, {
  Random? random,
}) async {
  // 보상이 연습을 막아서는 안 된다. 잔액을 들고 있는 쪽이 없으면(테스트나
  // Provider 밖에서 띄운 화면) 주지 않고 조용히 지나간다.
  final UserProvider provider;
  try {
    provider = context.read<UserProvider>();
  } catch (e) {
    AppLogger.d('[Reward] 잔액을 들고 있는 쪽이 없어 보상을 건너뜀: $e');
    return const RewardGrant(crackers: 0);
  }
  if (provider.currentUser == null) return const RewardGrant(crackers: 0);

  final grant =
      await PracticeRewardStore.prepare(accountId, random: random);
  if (grant.isEmpty) return grant;

  try {
    await provider.addCrackers(grant.crackers);
  } catch (e) {
    // 지급에 실패하면 장부도 그대로 둔다. 다음 연습에서 다시 받을 수 있다.
    AppLogger.e('[Reward] 연습 보상 지급 실패 crackers=${grant.crackers}', error: e);
    return const RewardGrant(crackers: 0);
  }
  await PracticeRewardStore.confirm(accountId, grant);

  // 오늘 받을 것을 다 받았으면, 오늘 남은 알림은 줄 것이 없는데도 부른다.
  // 그 자리에서 다시 깔아 오늘치를 지운다(5차 505).
  if (grant.cap == RewardCap.day) {
    await skipTodayPracticeReminders(accountId);
  }
  return grant;
}
