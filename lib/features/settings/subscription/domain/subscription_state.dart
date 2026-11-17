// 지금 구독이 어떤 상태인지. 서버(users/{uid}.subscription)가 정하고 앱은
// 읽기만 한다. 서버 값이 없으면 RevenueCat이 들고 있는 것을 쓰고, 그것도
// 없으면 무료로 본다(5차).

import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

/// 서버가 쓰는 상태 값과 같은 말.
enum SubscriptionStatus {
  /// 쓸 수 있다.
  active,

  /// 결제가 밀렸지만 아직 쓸 수 있다.
  grace,

  /// 해지를 예약했고 기간이 끝날 때까지 쓸 수 있다.
  canceled,

  /// 끝났다(환불 포함).
  expired,
}

/// entitlement 이름. 서버(functions/src/subscriptionEvent.ts)와 같아야 한다.
const String lightEntitlementId = 'parrokit_sub_light';
const String proEntitlementId = 'parrokit_sub_pro';

class SubscriptionState {
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.status = SubscriptionStatus.expired,
    this.periodEnd,
  });

  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? periodEnd;

  /// 지금 혜택을 쓸 수 있는지. 해지를 예약했거나 결제가 밀려도 기간 안에는 쓴다.
  bool get isActive =>
      tier != SubscriptionTier.free && status != SubscriptionStatus.expired;

  static const free = SubscriptionState();
}

SubscriptionTier _tierFromName(Object? value) {
  switch (value) {
    case 'pro':
      return SubscriptionTier.pro;
    case 'light':
      return SubscriptionTier.light;
    default:
      return SubscriptionTier.free;
  }
}

SubscriptionStatus _statusFromName(Object? value) {
  switch (value) {
    case 'active':
      return SubscriptionStatus.active;
    case 'grace':
      return SubscriptionStatus.grace;
    case 'canceled':
      return SubscriptionStatus.canceled;
    default:
      return SubscriptionStatus.expired;
  }
}

/// users/{uid}.subscription 맵을 읽는다. 없거나 모르는 값이면 무료.
SubscriptionState subscriptionFromServer(Map<String, dynamic>? map) {
  if (map == null) return SubscriptionState.free;
  final tier = _tierFromName(map['tier']);
  final status = _statusFromName(map['status']);
  final endMs = map['periodEnd'];
  return SubscriptionState(
    tier: tier,
    status: tier == SubscriptionTier.free ? SubscriptionStatus.expired : status,
    periodEnd: endMs is int
        ? DateTime.fromMillisecondsSinceEpoch(endMs)
        : (endMs is num
            ? DateTime.fromMillisecondsSinceEpoch(endMs.toInt())
            : null),
  );
}

/// RevenueCat이 들고 있는 entitlement로 본 상태. 서버 값이 아직 없을 때 쓴다.
SubscriptionState subscriptionFromEntitlements(Set<String> active) {
  if (active.contains(proEntitlementId)) {
    return const SubscriptionState(
        tier: SubscriptionTier.pro, status: SubscriptionStatus.active);
  }
  if (active.contains(lightEntitlementId)) {
    return const SubscriptionState(
        tier: SubscriptionTier.light, status: SubscriptionStatus.active);
  }
  return SubscriptionState.free;
}

/// 개발 빌드에서 단계를 바꿔 보는 길: --dart-define=PK_FAKE_TIER=pro
SubscriptionState? subscriptionFromFakeTier(String fakeTier) {
  switch (fakeTier) {
    case 'pro':
      return const SubscriptionState(
          tier: SubscriptionTier.pro, status: SubscriptionStatus.active);
    case 'light':
      return const SubscriptionState(
          tier: SubscriptionTier.light, status: SubscriptionStatus.active);
    case 'free':
      return SubscriptionState.free;
    default:
      return null;
  }
}

/// 무엇을 믿을지 정한다. 가짜 단계 > 서버 > RevenueCat > 무료.
///
/// 서버가 '무료'라고 적어 둔 것도 서버의 판단이므로 그대로 따른다. 서버에
/// 아직 아무 값이 없을 때만 RevenueCat을 본다.
SubscriptionState resolveSubscription({
  SubscriptionState? server,
  SubscriptionState? revenueCat,
  String fakeTier = const String.fromEnvironment('PK_FAKE_TIER'),
}) {
  final fake = subscriptionFromFakeTier(fakeTier);
  if (fake != null) return fake;
  if (server != null) return server;
  if (revenueCat != null) return revenueCat;
  return SubscriptionState.free;
}
