// ============================================================================
// lib/features/auth/domain/coin_package.dart
// ============================================================================
//
// [역할]
// 코인 충전 패키지 모델.
// 결제 금액, 기본 코인, 보너스 코인, RevenueCat 상품 ID 정보를 담고 있음.
//
// [레이어]
// Domain Layer - 비즈니스 로직에서 사용하는 순수 모델.
// ============================================================================

/// 코인 충전 패키지 모델.
class CoinPackage {
  /// RevenueCat (App Store / Play Store) 상품 ID
  final String productId;

  /// 결제 금액 (KRW, 원화) — UI 표시용
  final int price;

  /// 기본 지급 코인 수
  final int coins;

  /// 보너스 코인 수 (추가 지급)
  final int bonusCoins;

  const CoinPackage({
    required this.productId,
    required this.price,
    required this.coins,
    required this.bonusCoins,
  });

  /// 총 지급 코인 수 (기본 + 보너스)
  int get totalCoins => coins + bonusCoins;

  // ─────────────────────────────────────────────────────────────────
  // 사전 정의된 패키지 목록
  // ─────────────────────────────────────────────────────────────────

  /// 사전 정의된 코인 패키지 목록 (10% 보너스 적용)
  ///
  /// RevenueCat 대시보드에서 아래 productId로 Consumable 상품을 등록해야 함.
  ///
  /// | productId          | 가격    | 기본  | 보너스 | 총 코인 |
  /// |--------------------|---------|-------|--------|---------|
  /// | parrokit_coins_1   | ₩1,000  | 80    | 8      | 88      |
  /// | parrokit_coins_3   | ₩3,000  | 240   | 24     | 264     |
  /// | parrokit_coins_5   | ₩5,000  | 400   | 40     | 440     |
  /// | parrokit_coins_10  | ₩10,000 | 800   | 80     | 880     |
  static const List<CoinPackage> packages = [
    CoinPackage(
        productId: 'parrokit_coins_1', price: 1000, coins: 80, bonusCoins: 8),
    CoinPackage(
        productId: 'parrokit_coins_3', price: 3000, coins: 240, bonusCoins: 24),
    CoinPackage(
        productId: 'parrokit_coins_5', price: 5000, coins: 400, bonusCoins: 40),
    CoinPackage(
        productId: 'parrokit_coins_10',
        price: 10000,
        coins: 800,
        bonusCoins: 80),
  ];
}
