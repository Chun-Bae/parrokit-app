// 지금 구독이 어떤 상태인지 정하는 규칙. 서버가 먼저고, 없으면 RevenueCat,
// 그것도 없으면 무료다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_state.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

void main() {
  group('서버 값 읽기', () {
    test('단계와 상태, 기간 끝을 읽는다', () {
      final state = subscriptionFromServer({
        'tier': 'pro',
        'status': 'active',
        'periodEnd': 1764000000000,
      });
      expect(state.tier, SubscriptionTier.pro);
      expect(state.status, SubscriptionStatus.active);
      expect(state.periodEnd,
          DateTime.fromMillisecondsSinceEpoch(1764000000000));
      expect(state.isActive, isTrue);
    });

    test('해지 예약과 결제 밀림도 아직 쓸 수 있다', () {
      for (final status in ['canceled', 'grace']) {
        final state =
            subscriptionFromServer({'tier': 'light', 'status': status});
        expect(state.isActive, isTrue, reason: status);
      }
    });

    test('끝났으면 쓸 수 없다', () {
      final state =
          subscriptionFromServer({'tier': 'light', 'status': 'expired'});
      expect(state.isActive, isFalse);
    });

    test('무료면 상태도 끝난 것으로 둔다', () {
      final state =
          subscriptionFromServer({'tier': 'free', 'status': 'active'});
      expect(state.tier, SubscriptionTier.free);
      expect(state.status, SubscriptionStatus.expired);
      expect(state.isActive, isFalse);
    });

    test('값이 없거나 모르는 말이면 무료', () {
      expect(subscriptionFromServer(null).tier, SubscriptionTier.free);
      expect(subscriptionFromServer({'tier': 'platinum'}).tier,
          SubscriptionTier.free);
      expect(subscriptionFromServer({}).periodEnd, isNull);
    });
  });

  group('RevenueCat 값 읽기', () {
    test('프로가 라이트보다 앞선다', () {
      final state = subscriptionFromEntitlements(
          {lightEntitlementId, proEntitlementId});
      expect(state.tier, SubscriptionTier.pro);
    });

    test('구독 entitlement가 없으면 무료', () {
      expect(subscriptionFromEntitlements({'parrokit_ads_removed'}).tier,
          SubscriptionTier.free);
      expect(subscriptionFromEntitlements(<String>{}).tier,
          SubscriptionTier.free);
    });
  });

  group('무엇을 믿을지', () {
    const server = SubscriptionState(
        tier: SubscriptionTier.light, status: SubscriptionStatus.active);
    const rc = SubscriptionState(
        tier: SubscriptionTier.pro, status: SubscriptionStatus.active);

    test('서버 값이 있으면 서버를 따른다', () {
      final state =
          resolveSubscription(server: server, revenueCat: rc, fakeTier: '');
      expect(state.tier, SubscriptionTier.light);
    });

    test('서버가 무료라고 해도 그대로 따른다', () {
      final state = resolveSubscription(
          server: SubscriptionState.free, revenueCat: rc, fakeTier: '');
      expect(state.tier, SubscriptionTier.free);
    });

    test('서버 값이 아직 없으면 RevenueCat을 본다', () {
      final state = resolveSubscription(revenueCat: rc, fakeTier: '');
      expect(state.tier, SubscriptionTier.pro);
    });

    test('둘 다 없으면 무료', () {
      expect(resolveSubscription(fakeTier: '').tier, SubscriptionTier.free);
    });

    test('개발 빌드의 가짜 단계가 가장 앞선다', () {
      final state = resolveSubscription(
          server: server, revenueCat: rc, fakeTier: 'free');
      expect(state.tier, SubscriptionTier.free);
      expect(
          resolveSubscription(server: server, fakeTier: 'pro').tier,
          SubscriptionTier.pro);
    });
  });
}
