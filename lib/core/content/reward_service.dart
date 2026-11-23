// 크래커 보상을 서버에서 받아 오는 길(5차 568).
//
// 전에는 앱이 뽑고 앱이 Firestore에 더했다. 뽑기 표도 상한 장부도 기기
// 안(SharedPreferences)에 있어서, 마음먹으면 얼마든지 올릴 수 있었다.
// 크래커는 환전으로 패롯이 되고, 패롯은 Whisper·Gemini·R2를 쓰는 값이라
// 그만큼 서버 비용이 나간다.
//
// 이제 뽑기와 상한은 서버가 쥔다. 앱은 '한 번 연습했다', '지금 레벨이
// 이만큼이다'라고만 말한다. 레벨은 아직 기기 안 XP로 세지만, 보따리는
// 표로 고정돼 있어 표 바깥으로는 못 간다.

import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/remote_call_timeout.dart';

import 'practice_reward.dart';

/// 보상 요청이 너무 오래 걸리면 끊는다. 연습 흐름을 붙잡지 않는다.
const Duration rewardCallTimeout = shortCallTimeout;

final Random _rand = Random();

/// 두 번 눌러도 한 번만 받게 하는 요청 id. 서버가 장부 키로 쓴다.
String newRewardRequestId() =>
    'rw${DateTime.now().millisecondsSinceEpoch}${_rand.nextInt(1 << 20)}';

/// 서버가 돌려준 상한 이름을 앱의 것으로 옮긴다. 모르면 null.
RewardCap? rewardCapFrom(Object? value) => switch (value) {
      'day' => RewardCap.day,
      'week' => RewardCap.week,
      'month' => RewardCap.month,
      _ => null,
    };

/// 크래커 보상을 서버에 청한다.
class RewardService {
  RewardService({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _fn => _functions ?? FirebaseFunctions.instance;

  /// 연습 한 번의 보상을 받는다. 뽑기와 상한은 서버가 정한다.
  ///
  /// 못 받으면 빈 [RewardGrant]다. 보상이 연습을 막아서는 안 되므로
  /// 실패는 조용히 넘어간다.
  Future<RewardGrant> practiceReward({
    required int level,
    String? requestId,
  }) async {
    try {
      final result = await _fn
          .httpsCallable('grantPracticeReward')
          .call<Map<Object?, Object?>>({
        'level': level,
        'requestId': requestId ?? newRewardRequestId(),
      }).timeout(rewardCallTimeout);
      final data = Map<String, dynamic>.from(result.data);
      return RewardGrant(
        crackers: (data['crackers'] as num?)?.toInt() ?? 0,
        rolled: (data['rolled'] as num?)?.toInt() ?? 0,
        cap: rewardCapFrom(data['cap']),
      );
    } catch (e) {
      AppLogger.w('[Reward] 연습 보상을 받지 못했어요: $e');
      return const RewardGrant(crackers: 0);
    }
  }

  /// 밀린 레벨 보따리를 받는다. 받을 것이 없으면 0.
  ///
  /// 서버가 처음 보는 사람은 지금 레벨까지 이미 받은 것으로 적고 0을
  /// 돌려준다. 소급해 주면 이미 높은 레벨인 사람이 표 전체를 한꺼번에
  /// 받는다.
  Future<int> levelReward({
    required int level,
    String? requestId,
  }) async {
    try {
      final result = await _fn
          .httpsCallable('claimLevelReward')
          .call<Map<Object?, Object?>>({
        'level': level,
        'requestId': requestId ?? newRewardRequestId(),
      }).timeout(rewardCallTimeout);
      final data = Map<String, dynamic>.from(result.data);
      return (data['crackers'] as num?)?.toInt() ?? 0;
    } catch (e) {
      AppLogger.w('[Level] 보따리를 받지 못했어요: $e');
      return 0;
    }
  }
}
