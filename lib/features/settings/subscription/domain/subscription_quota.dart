// 단계별로 서버에 담을 수 있는 양. 서버(functions/src/storageUsage.ts)와 같은 값이다.
//
// 실제로 막는 것은 서버다. 앱은 보여 주기만 한다.

import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

const int _gb = 1024 * 1024 * 1024;

/// 이 단계가 서버에 담을 수 있는 양(바이트). 무료는 서버에 담지 않는다.
int serverStorageQuotaBytes(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return 0;
    case SubscriptionTier.light:
      return 5 * _gb;
    case SubscriptionTier.pro:
      return 30 * _gb;
  }
}

/// 서버 저장 줄에 적을 말. 무료는 담을 곳이 없다는 것을 먼저 알린다.
String serverStorageSubtitle(SubscriptionTier tier) =>
    tier == SubscriptionTier.free
        ? '구독하면 영상이 서버에 백업돼요. 지금은 이 기기에만 있어요.'
        : '앱 서버에 저장된 파일과 정보';

/// 단계별로 매달 받는 패롯. 서버(functions/src/subscriptionGrant.ts의
/// DEFAULT_GRANTS)와 같은 값이다. 실제로 주는 것은 서버다.
int monthlyParrotsFor(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return 0;
    case SubscriptionTier.light:
      return 100;
    case SubscriptionTier.pro:
      return 400;
  }
}

/// 서버 저장 한도를 'GB'로 적는다. 구독 고르기 화면의 혜택 줄에 쓴다.
String serverStorageQuotaLabel(SubscriptionTier tier) {
  final gb = serverStorageQuotaBytes(tier) ~/ _gb;
  return '${gb}GB';
}
