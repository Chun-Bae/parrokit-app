// 구독 Provider가 서버 문서를 지켜보는지.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('서버에 적힌 단계를 그대로 쓴다', () async {
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'pro', 'status': 'active'},
    });
    final provider = SubscriptionProvider(firestore: db);
    addTearDown(provider.dispose);

    provider.syncUser('uid-1');
    await settle();

    expect(provider.tier, SubscriptionTier.pro);
    expect(provider.isSubscribed, isTrue);
  });

  test('서버 값이 바뀌면 따라 바뀐다', () async {
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'light', 'status': 'active'},
    });
    final provider = SubscriptionProvider(firestore: db);
    addTearDown(provider.dispose);
    provider.syncUser('uid-1');
    await settle();
    expect(provider.tier, SubscriptionTier.light);

    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'free', 'status': 'expired'},
    });
    await settle();
    expect(provider.tier, SubscriptionTier.free);
    expect(provider.isSubscribed, isFalse);
  });

  test('서버에 구독 칸이 없으면 RevenueCat 값을 쓴다', () async {
    await db.collection('users').doc('uid-1').set({'nickname': '춘배'});
    final provider = SubscriptionProvider(firestore: db);
    addTearDown(provider.dispose);

    provider.syncUser('uid-1');
    provider.applyEntitlements({'parrokit_sub_light'});
    await settle();

    expect(provider.tier, SubscriptionTier.light);
  });

  test('로그아웃하면 무료로 돌아간다', () async {
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'pro', 'status': 'active'},
    });
    final provider = SubscriptionProvider(firestore: db);
    addTearDown(provider.dispose);
    provider.syncUser('uid-1');
    await settle();
    expect(provider.tier, SubscriptionTier.pro);

    provider.syncUser(null);
    await settle();
    expect(provider.tier, SubscriptionTier.free);
  });

  test('다른 사람으로 바뀌면 그 사람 문서를 본다', () async {
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'pro', 'status': 'active'},
    });
    await db.collection('users').doc('uid-2').set({
      'subscription': {'tier': 'light', 'status': 'active'},
    });
    final provider = SubscriptionProvider(firestore: db);
    addTearDown(provider.dispose);

    provider.syncUser('uid-1');
    await settle();
    provider.syncUser('uid-2');
    await settle();

    expect(provider.tier, SubscriptionTier.light);
  });
}
