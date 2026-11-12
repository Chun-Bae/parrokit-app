// ============================================================================
// lib/core/provider/iap_provider.dart
// ============================================================================
//
// [역할]
// RevenueCat 기반 프리미엄(구독) 상태 관리.
// CustomerInfo 업데이트를 실시간으로 수신하여 isPremium 상태를 유지.
//
// [엔타이틀먼트]
// RevenueCat 대시보드 entitlement ID: "parrokit_ads_removed"
//
// [레이어]
// Core Layer > Provider
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

class IapProvider extends ChangeNotifier {
  static const String entitlementId = 'parrokit_ads_removed';

  bool isPremium = false;
  bool loading = true;
  bool available = true;

  Future<void> init() async {
    loading = true;
    notifyListeners();

    try {
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
    } catch (e) {
      AppLogger.e('[IAP] 초기 구매 정보 조회 실패', error: e);
    }

    Purchases.addCustomerInfoUpdateListener(_applyCustomerInfo);

    loading = false;
    notifyListeners();
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.active.containsKey(entitlementId);
    if (isPremium == active) return;
    isPremium = active;
    AppLogger.i('[IAP] isPremium updated: $isPremium');
    notifyListeners();
  }

  /// 구매 내역 복원.
  Future<void> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
    } catch (e) {
      AppLogger.e('[IAP] 구매 복원 실패', error: e);
    }
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_applyCustomerInfo);
    super.dispose();
  }
}
