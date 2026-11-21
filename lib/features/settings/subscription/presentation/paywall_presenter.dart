// 구독 화면을 여는 길. 둘 중 하나를 쓴다.
//
// - 진짜: RevenueCat Paywall(대시보드에서 만든 화면). 출시 빌드는 늘 이것.
// - 미리보기: 우리가 만든 시트. 스토어 상품과 Paywall이 준비되기 전까지
//   개발 빌드에서 화면과 글귀를 확인하는 용도.
//
// 바꾸는 법: --dart-define=PK_REAL_PAYWALL=true 로 개발 빌드에서도 진짜를 띄운다.

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:parrokit/core/shared/utils/remote_call_timeout.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_state.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_preview_sheet.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

abstract class PaywallPresenter {
  Future<void> show(BuildContext context);
}

class RevenueCatPaywallPresenter implements PaywallPresenter {
  const RevenueCatPaywallPresenter();

  /// 구독 화면이 뜨지 않으면 까닭을 알린다(5차 355).
  ///
  /// 스토어 상품이나 RevenueCat Paywall이 아직 없으면 이 함수는 조용히
  /// `notPresented`를 돌려준다. 그러면 사용자가 '구독'을 눌러도 아무 일도
  /// 일어나지 않아 고장처럼 보였다. 이미 구독 중일 때도 같은 값이 와서,
  /// 그 둘을 나눠 말해 준다.
  ///
  /// 구독 여부는 **구독 단계**로 따진다(5차 459). 전에는
  /// `presentPaywallIfNeeded(IapProvider.entitlementId)`를 불렀는데 그 값은
  /// 광고 제거(1회 구매) entitlement라, 구독한 사람에게도 Paywall이 뜨고
  /// 광고 제거만 산 사람에게는 안 떴다.
  @override
  Future<void> show(BuildContext context) async {
    final premium = isSubscribedNow(context);
    if (premium) {
      showToast(subscriptionAlreadyToast);
      return;
    }
    PaywallResult result;
    try {
      // 어느 화면을 띄울지 꼭 짚어 준다(5차 461).
      //
      // 그냥 presentPaywall()을 부르면 RevenueCat이 **지금 기본 offering**의
      // 화면을 띄운다. 이 프로젝트의 기본은 광고 제거(1회 구매)라, 구독을
      // 누르면 '한 번 구매로 평생 광고 제거'가 떴다(기기에서 봤다).
      final offerings =
          await Purchases.getOfferings().timeout(shortCallTimeout);
      final offering = offerings.all[subscriptionOfferingId];
      if (offering == null) {
        showToast(subscriptionNotReadyToast);
        return;
      }
      result = await RevenueCatUI.presentPaywall(offering: offering);
    } catch (_) {
      showToast(subscriptionOpenFailedToast);
      return;
    }
    if (result != PaywallResult.notPresented) return;
    showToast(subscriptionNotReadyToast);
  }
}

/// 구독 화면이 붙어 있는 offering. RevenueCat 대시보드와 같아야 한다.
const String subscriptionOfferingId = 'parrokit_subscription';

/// 지금 구독 중인지. 서버가 적어 준 단계를 먼저 보고, 아직 없으면
/// RevenueCat이 들고 있는 entitlement로 본다(5차 459).
bool isSubscribedNow(BuildContext context) {
  final byServer = context.read<SubscriptionProvider?>()?.isSubscribed;
  if (byServer == true) return true;
  final active = context.read<IapProvider?>()?.activeEntitlements ?? const {};
  return active.any(subscriptionEntitlementIds.contains);
}

class PreviewPaywallPresenter implements PaywallPresenter {
  const PreviewPaywallPresenter();

  @override
  Future<void> show(BuildContext context) =>
      showSubscriptionPreviewSheet(context);
}

const bool kRealPaywall = bool.fromEnvironment('PK_REAL_PAYWALL');

/// 출시 빌드이거나 PK_REAL_PAYWALL이면 진짜 Paywall, 그 밖에는 미리보기.
bool usesRealPaywall({
  bool releaseMode = kReleaseMode,
  bool realPaywallFlag = kRealPaywall,
}) =>
    releaseMode || realPaywallFlag;

PaywallPresenter resolvePaywallPresenter({
  bool releaseMode = kReleaseMode,
  bool realPaywallFlag = kRealPaywall,
}) =>
    usesRealPaywall(releaseMode: releaseMode, realPaywallFlag: realPaywallFlag)
        ? const RevenueCatPaywallPresenter()
        : const PreviewPaywallPresenter();
