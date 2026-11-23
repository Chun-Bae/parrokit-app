import 'package:flutter/widgets.dart';
import 'package:parrokit/core/content/practice_reward.dart';
import 'package:parrokit/core/content/reward_service.dart';
import 'package:parrokit/core/content/speaking_xp.dart';
import 'package:parrokit/core/infrastructure/services/local_notification_service.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';

/// 연습 한 번에 크래커를 받아 온다(5차 505, 서버로 옮김 5차 568).
///
/// 뽑기와 상한은 **서버**가 쥔다([RewardService]). 전에는 앱이 뽑고 앱이
/// Firestore에 더했는데, 뽑기 표도 장부도 기기 안에 있어서 마음먹으면
/// 올릴 수 있었다. 크래커는 환전으로 패롯이 되고, 패롯은 Whisper·Gemini·
/// R2를 쓰는 값이라 그만큼 서버 비용이 된다.
///
/// 돌려주는 [RewardGrant]로 화면이 무엇을 보여 줄지 정한다.
/// - [RewardGrant.isEmpty]면 줄 것이 없다(상한을 다 썼거나 받기가 실패).
/// - [RewardGrant.capped]면 상한에 걸려 깎였다.
///
/// [context]는 await 전에 읽는다. 연습을 마치고 시트가 닫힐 수 있다.
Future<RewardGrant> grantPracticeReward(
  BuildContext context,
  String accountId, {
  RewardService? service,
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

  // 레벨이 오르면 하루 상한이 늘어난다(5차 566). 서버가 300~600으로 끊고,
  // 주·달 상한은 서버가 쥐고 있어 한 달 총량은 움직이지 않는다.
  final level = levelForXp(await loadParrotXp(accountId));
  final grant = await (service ?? RewardService()).practiceReward(level: level);
  if (grant.isEmpty) return grant;

  // 잔액은 서버가 올렸다. 화면은 사용자 문서 구독(watchUserById)으로
  // 곧 따라온다 - 앱이 따로 더하지 않는다.

  // 오늘 받을 것을 다 받았으면, 오늘 남은 알림은 줄 것이 없는데도 부른다.
  // 그 자리에서 다시 깔아 오늘치를 지운다(5차 505).
  if (grant.cap == RewardCap.day) {
    await skipTodayPracticeReminders(accountId);
  }
  return grant;
}
