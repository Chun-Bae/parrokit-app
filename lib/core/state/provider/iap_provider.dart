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

  /// 지금 켜져 있는 entitlement 이름들. 구독 단계를 서버가 아직 안 적었을 때
  /// 이 값으로 단계를 본다(5차).
  Set<String> activeEntitlements = const {};

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
    final entitlements = info.entitlements.active.keys.toSet();
    final active = entitlements.contains(entitlementId);
    final sameEntitlements = entitlements.length == activeEntitlements.length &&
        entitlements.containsAll(activeEntitlements);
    if (isPremium == active && sameEntitlements) return;
    isPremium = active;
    activeEntitlements = entitlements;
    AppLogger.i('[IAP] isPremium updated: $isPremium');
    notifyListeners();
  }

  /// 구매 내역 복원. 스토어까지 다녀왔으면 true, 실패했으면 false(5차 356).
  ///
  /// 전에는 실패해도 조용히 넘겨서, 화면이 '복원할 구독을 찾지 못했어요'라고
  /// 말했다. 인터넷이 끊겼을 때와 살 것이 없을 때를 가려 말해야 한다.
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      return true;
    } catch (e) {
      AppLogger.e('[IAP] 구매 복원 실패', error: e);
      return false;
    }
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_applyCustomerInfo);
    super.dispose();
  }
}
