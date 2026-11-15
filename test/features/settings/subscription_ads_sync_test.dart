// 구독 중이면 광고가 꺼져야 한다. 예전 1회 구매(parrokit_ads_removed)도 그대로 받는다.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/state/di/providers.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/collection/clip/shorts/data/shorts_ad_repository.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/ad_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

class _MemoryAdRepository extends ShortsAdRepository {
  int count = 0;
  int? lastAdMs;

  @override
  Future<int> loadCount() async => count;

  @override
  Future<void> saveCount(int count) async => this.count = count;

  @override
  Future<void> clearCount() async => count = 0;

  @override
  Future<int?> loadLastAdTime() async => lastAdMs;

  @override
  Future<void> saveLastAdTime(int millisecondsSinceEpoch) async =>
      lastAdMs = millisecondsSinceEpoch;
}

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeFirebaseFirestore db;
  late AdProvider ads;
  late IapProvider iap;
  late SubscriptionProvider sub;

  setUp(() async {
    db = FakeFirebaseFirestore();
    ads = AdProvider(repository: _MemoryAdRepository(), initialPremium: false);
    iap = IapProvider();
    sub = SubscriptionProvider(firestore: db);
    sub.addListener(() => syncAdsPremium(ads, iap, sub));
    await settle();
  });

  tearDown(() {
    sub.dispose();
    ads.dispose();
  });

  test('무료이고 광고 제거도 없으면 광고를 본다', () async {
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'free', 'status': 'expired'},
    });
    sub.syncUser('uid-1');
    await settle();

    expect(ads.premium, isFalse);
  });

  test('구독 중이면 광고를 끈다', () async {
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'light', 'status': 'active'},
    });
    sub.syncUser('uid-1');
    await settle();

    expect(ads.premium, isTrue);
  });

  test('구독이 끝나면 광고가 다시 켜진다', () async {
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'pro', 'status': 'active'},
    });
    sub.syncUser('uid-1');
    await settle();
    expect(ads.premium, isTrue);

    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'free', 'status': 'expired'},
    });
    await settle();
    expect(ads.premium, isFalse);
  });

  test('구독이 없어도 예전 1회 구매가 있으면 광고를 끈다', () async {
    iap.isPremium = true;
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'free', 'status': 'expired'},
    });
    sub.syncUser('uid-1');
    await settle();

    expect(ads.premium, isTrue);
  });

  test('서버가 아직 안 적었으면 RevenueCat entitlement로 끈다', () async {
    await db.collection('users').doc('uid-1').set({'nickname': '춘배'});
    sub.syncUser('uid-1');
    sub.applyEntitlements({'parrokit_sub_pro'});
    await settle();

    expect(ads.premium, isTrue);
  });
}
