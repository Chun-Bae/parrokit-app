// 가게 화면(RevenueCat Paywall)을 여는 한 가지 길(5차 464).
//
// 어느 화면을 띄울지 꼭 짚어 준다. 인자 없이 presentPaywall()을 부르면
// 지금 기본 offering의 화면이 뜨는데, 이 프로젝트의 기본은 광고 제거다.
// 그래서 구독을 눌렀더니 '평생 광고 제거'가 떴다(5차 461).
//
// 광고 제거와 패롯 충전이 같은 흐름을 두 벌로 적지 않도록 여기 모은다.

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:parrokit/core/shared/utils/remote_call_timeout.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

/// RevenueCat 대시보드의 offering 이름들. 거기와 같아야 한다.
const String adsRemovalOfferingId = 'parrokit_ads_removed';
const String parrotStoreOfferingId = 'parrokit_coins';

/// 띄우지 못했을 때 할 말.
const String adsRemovalNotReadyToast = '지금은 광고 제거를 살 수 없어요. 잠시 뒤 다시 해 주세요.';
const String parrotStoreNotReadyToast = '지금은 패롯을 충전할 수 없어요. 잠시 뒤 다시 해 주세요.';

/// [offeringId]에 붙은 화면을 띄운다. 그 offering이 없으면 엉뚱한 화면을
/// 띄우지 않고 까닭을 말한다.
Future<void> showOfferingPaywall(
  BuildContext context, {
  required String offeringId,
  required String notReadyToast,
}) async {
  try {
    final offerings = await Purchases.getOfferings().timeout(shortCallTimeout);
    final offering = offerings.all[offeringId];
    if (offering == null) {
      showToast(notReadyToast);
      return;
    }
    await RevenueCatUI.presentPaywall(offering: offering);
  } catch (_) {
    showToast(notReadyToast);
  }
}

/// 광고 제거 화면.
Future<void> showAdsRemovalPaywall(BuildContext context) => showOfferingPaywall(
      context,
      offeringId: adsRemovalOfferingId,
      notReadyToast: adsRemovalNotReadyToast,
    );

/// 패롯 충전 화면.
Future<void> showParrotStorePaywall(BuildContext context) =>
    showOfferingPaywall(
      context,
      offeringId: parrotStoreOfferingId,
      notReadyToast: parrotStoreNotReadyToast,
    );
