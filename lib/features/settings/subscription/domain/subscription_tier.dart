// 구독 단계 이름과 광고 판단.
//
// 지금 단계가 무엇인지는 서버가 정하고 SubscriptionProvider가 들고 있다(5차 2단계).

/// 낮은 단계부터. 서버(functions/src/subscriptionTier.ts의 TIER_KEYS)와 같은 순서.
enum SubscriptionTier { free, light, plus, pro, max }

/// 가장 높은 단계인지. 여기서는 더 올릴 데가 없다.
bool isTopTier(SubscriptionTier tier) => tier == SubscriptionTier.max;

/// 광고를 보여 줄지. 구독자이거나 예전 1회 구매자면 안 보여 준다.
bool showsAds({required SubscriptionTier tier, required bool adsRemoved}) =>
    tier == SubscriptionTier.free && !adsRemoved;
