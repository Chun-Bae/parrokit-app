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
      return 10 * _gb;
    case SubscriptionTier.plus:
      return 20 * _gb;
    case SubscriptionTier.pro:
      return 30 * _gb;
    case SubscriptionTier.max:
      return 80 * _gb;
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
    case SubscriptionTier.plus:
      return 250;
    case SubscriptionTier.pro:
      return 400;
    case SubscriptionTier.max:
      return 700;
  }
}

/// 단계별로 하루에 만들 수 있는 예문 수. 서버(functions/src/exampleQuota.ts의
/// DEFAULT_EXAMPLE_LIMITS)와 같은 값이다. 실제로 세는 것은 서버다.
/// 뜻·발음 채우기 하루 한도와는 다른 축이다.
int dailyExamplesFor(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      // 5개는 낱말당 3개 상한 때문에 단어 두 개도 못 채웠다(5차 532).
      return 10;
    case SubscriptionTier.light:
      return 30;
    case SubscriptionTier.plus:
      return 80;
    case SubscriptionTier.pro:
      return 200;
    case SubscriptionTier.max:
      return 500;
  }
}

/// 단계별로 하루에 쓸 수 있는 뜻·발음 채우기 횟수. 서버
/// (functions/src/subscriptionTier.ts의 DEFAULT_ASSIST_LIMITS)와 같은 값이다.
///
/// 예문 하루 한도와 **다른 축**이다. 둘은 서로 깎지 않는다. 전에는 구독
/// 화면이 이 수를 적지 않고 '뜻 채우기 하루 한도가 늘어요'로 뭉뚱그려서,
/// 무엇이 얼마나 늘어나는지 알 수 없었다(5차 531).
int dailyAssistFor(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return 3;
    case SubscriptionTier.light:
      return 15;
    case SubscriptionTier.plus:
      return 30;
    case SubscriptionTier.pro:
      return 60;
    case SubscriptionTier.max:
      return 120;
  }
}

/// 단계별 낱말당 예문 상한. 서버 DEFAULT_EXAMPLES_PER_WORD와 같은 값.
int examplesPerWordFor(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return 3;
    case SubscriptionTier.light:
      return 5;
    case SubscriptionTier.plus:
    case SubscriptionTier.pro:
    case SubscriptionTier.max:
      return 10;
  }
}

/// 서버 저장 한도를 'GB'로 적는다. 구독 고르기 화면의 혜택 줄에 쓴다.
String serverStorageQuotaLabel(SubscriptionTier tier) {
  final gb = serverStorageQuotaBytes(tier) ~/ _gb;
  return '${gb}GB';
}
