// 구독 관리와 구매 복원. 둘 다 스토어·RevenueCat이 맡는 일이라 앱은 열어 주기만 한다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

/// 스토어의 구독 관리 화면(해지·단계 바꾸기)을 연다.
Future<void> openStoreSubscriptions(BuildContext context) async {
  try {
    await RevenueCatUI.presentCustomerCenter();
  } catch (error) {
    AppLogger.w('[Subscription] 구독 관리 화면을 열지 못했어요: $error');
    if (!context.mounted) return;
    showToast('지금은 구독 관리 화면을 열 수 없어요. 스토어 설정에서 바꿀 수 있어요.');
  }
}

/// 이미 산 구독을 이 기기에 다시 가져온다.
Future<void> restorePurchases(BuildContext context) async {
  final provider = context.read<IapProvider>();
  // 실패와 '살 것이 없음'을 가려 말한다(5차 356). 전에는 둘 다 '찾지
  // 못했어요'라고 해서, 인터넷이 끊겼을 때도 구독이 없는 줄 알았다.
  final reached = await provider.restorePurchases();
  if (!context.mounted) return;
  if (!reached) {
    showToast(subscriptionRestoreFailedToast);
    return;
  }
  showToast(provider.activeEntitlements.isEmpty
      ? subscriptionRestoreNoneToast
      : subscriptionRestoreDoneToast);
}
