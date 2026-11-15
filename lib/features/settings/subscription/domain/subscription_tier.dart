// 구독 단계. 2단계에서 서버(users/{uid}.subscription)가 정하게 바뀌지만,
// 그때까지 화면이 쓸 수 있도록 이름과 기본 판단만 먼저 둔다.

enum SubscriptionTier { free, light, pro }

/// 개발 빌드에서 단계를 바꿔 보는 길: --dart-define=PK_FAKE_TIER=pro
const String _fakeTier = String.fromEnvironment('PK_FAKE_TIER');

/// 지금 단계. 서버 값이 생기기 전까지는 '광고 제거를 산 사람'만 유료로 본다.
///
/// [adsRemoved]는 예전 1회 구매(entitlement parrokit_ads_removed)다. 그 사람은
/// 구독을 하지 않아도 광고가 없어야 해서 따로 들고 간다.
SubscriptionTier currentSubscriptionTier({
  required bool adsRemoved,
  String fakeTier = _fakeTier,
}) {
  switch (fakeTier) {
    case 'light':
      return SubscriptionTier.light;
    case 'pro':
      return SubscriptionTier.pro;
    case 'free':
      return SubscriptionTier.free;
  }
  // 구독이 아직 없으므로 1회 구매는 단계를 올리지 않는다. 광고만 없앤다.
  return SubscriptionTier.free;
}

/// 광고를 보여 줄지. 구독자이거나 예전 1회 구매자면 안 보여 준다.
bool showsAds({required SubscriptionTier tier, required bool adsRemoved}) =>
    tier == SubscriptionTier.free && !adsRemoved;
