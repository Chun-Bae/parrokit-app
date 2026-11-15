// 구독 화면을 여는 길. 둘 중 하나를 쓴다.
//
// - 진짜: RevenueCat Paywall(대시보드에서 만든 화면). 출시 빌드는 늘 이것.
// - 미리보기: 우리가 만든 시트. 스토어 상품과 Paywall이 준비되기 전까지
//   개발 빌드에서 화면과 글귀를 확인하는 용도.
//
// 바꾸는 법: --dart-define=PK_REAL_PAYWALL=true 로 개발 빌드에서도 진짜를 띄운다.

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_preview_sheet.dart';

abstract class PaywallPresenter {
  Future<void> show(BuildContext context);
}

class RevenueCatPaywallPresenter implements PaywallPresenter {
  const RevenueCatPaywallPresenter();

  @override
  Future<void> show(BuildContext context) =>
      RevenueCatUI.presentPaywallIfNeeded(IapProvider.entitlementId);
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
    usesRealPaywall(
            releaseMode: releaseMode, realPaywallFlag: realPaywallFlag)
        ? const RevenueCatPaywallPresenter()
        : const PreviewPaywallPresenter();
