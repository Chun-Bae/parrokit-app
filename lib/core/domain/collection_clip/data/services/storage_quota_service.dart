// 서버에 올리기 전에 "들어갈 자리가 있는지" 서버에 묻는다(5차 구독 3단계).
//
// 앱이 자기 기기 목록을 더해 세던 값은 기기마다 다르고 앱이 고치면 그만이라
// 한도의 근거가 못 된다. 쓴 양과 한도는 서버 값만 본다. 앱이 보내는 것은
// "이만큼 올리려 한다"는 크기뿐이다.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

class StorageQuotaResult {
  const StorageQuotaResult({
    required this.allowed,
    required this.usedBytes,
    required this.quotaBytes,
    required this.remainingBytes,
    required this.tier,
  });

  final bool allowed;
  final int usedBytes;
  final int quotaBytes;
  final int remainingBytes;
  final String tier;

  /// 서버가 답하지 않을 때. 막지 않고 그대로 올려 본다(올라가면 서버가 센다).
  static const unknown = StorageQuotaResult(
    allowed: true,
    usedBytes: 0,
    quotaBytes: 0,
    remainingBytes: 0,
    tier: 'unknown',
  );

  bool get isUnknown => tier == 'unknown';
}

/// 서버 저장 자리가 없을 때 띄울 말. 구독하지 않았으면 그 길을 알려 준다.
String storageQuotaMessage(StorageQuotaResult result) => result.quotaBytes == 0
    ? '서버 저장은 구독하면 쓸 수 있어요. 이 영상은 기기에 그대로 있어요.'
    : '서버가 가득 찼어요. 안 보는 영상을 지우거나 더 큰 단계로 올리면 담을 수 있어요.';

class StorageQuotaService {
  StorageQuotaService({FirebaseFunctions? functions}) : _given = functions;

  // Firebase가 준비되기 전에 만들어질 수 있어서(테스트, 앱 시작 전) 쓸 때 찾는다.
  final FirebaseFunctions? _given;
  FirebaseFunctions get _functions => _given ?? FirebaseFunctions.instance;

  Future<StorageQuotaResult> check({required int bytes}) async {
    try {
      final result = await _functions
          .httpsCallable('checkStorageQuota')
          .call<Map<Object?, Object?>>({'bytes': bytes});
      final data = Map<String, dynamic>.from(result.data);
      return StorageQuotaResult(
        allowed: data['allowed'] == true,
        usedBytes: (data['usedBytes'] as num?)?.toInt() ?? 0,
        quotaBytes: (data['quotaBytes'] as num?)?.toInt() ?? 0,
        remainingBytes: (data['remainingBytes'] as num?)?.toInt() ?? 0,
        tier: data['tier']?.toString() ?? 'free',
      );
    } catch (error) {
      // 서버에 못 물어봤다고 저장을 막지는 않는다. 올라가면 서버가 센다.
      AppLogger.w('[Clip][Storage] 남은 용량을 묻지 못했어요: $error');
      return StorageQuotaResult.unknown;
    }
  }
}
