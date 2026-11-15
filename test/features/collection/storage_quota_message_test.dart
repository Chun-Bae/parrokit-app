// 서버에 올리기 전에 묻는 자리 검사와, 자리가 없을 때 하는 말.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/services/storage_quota_service.dart';

const int gb = 1024 * 1024 * 1024;

StorageQuotaResult result({
  required bool allowed,
  int quotaBytes = 5 * gb,
  int remainingBytes = 0,
  String tier = 'light',
}) =>
    StorageQuotaResult(
      allowed: allowed,
      usedBytes: quotaBytes - remainingBytes,
      quotaBytes: quotaBytes,
      remainingBytes: remainingBytes,
      tier: tier,
    );

void main() {
  test('구독하지 않았으면 구독하면 쓸 수 있다고 알린다', () {
    final message =
        storageQuotaMessage(result(allowed: false, quotaBytes: 0, tier: 'free'));

    expect(message, contains('구독하면'));
    expect(message, contains('기기에 그대로'), reason: '영상이 사라지지 않는다는 것을 함께 알린다');
  });

  test('구독자에게는 정리하거나 올리는 길을 알린다', () {
    final message = storageQuotaMessage(result(allowed: false));

    expect(message, contains('가득 찼어요'));
    expect(message, isNot(contains('구독하면')));
  });

  test('말투는 앱과 같다(~어요)', () {
    for (final tier in ['free', 'light', 'pro']) {
      final message = storageQuotaMessage(
          result(allowed: false, quotaBytes: tier == 'free' ? 0 : 5 * gb));
      expect(message.endsWith('어요.') || message.contains('어요.'), isTrue,
          reason: tier);
      expect(message, isNot(contains('쿼터')));
      expect(message, isNot(contains('스토리지')));
    }
  });

  test('서버에 못 물어봤으면 막지 않는다', () {
    expect(StorageQuotaResult.unknown.allowed, isTrue);
    expect(StorageQuotaResult.unknown.isUnknown, isTrue);
  });
}
