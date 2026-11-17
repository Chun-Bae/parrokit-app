// 구독하면 서버 저장이 열린다(5차 457).
//
// 구독 화면은 '서버 백업 5GB·30GB'를 혜택으로 내거는데, 보관함의 서버
// 잠금은 티어를 보지 않았다. 그래서 구독해도 서버에 둔 클립을 불러오지도
// 못했다. 실제로 한도를 막는 것은 서버이고 앱은 보여 줄지만 정한다.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

Future<SubscriptionProvider> _provider({required String tier}) async {
  final store = FakeFirebaseFirestore();
  await store.collection('users').doc('uid-1').set({
    'subscription': {'tier': tier, 'status': 'active'},
  });
  final provider = SubscriptionProvider(firestore: store);
  addTearDown(provider.dispose);
  provider.syncUser('uid-1');
  await Future<void>.delayed(const Duration(milliseconds: 40));
  return provider;
}

void main() {
  setUp(() => ClipStorageConstants.isSubscriber = false);
  tearDown(() => ClipStorageConstants.isSubscriber = false);

  test('구독 전에는 잠겨 있다', () {
    expect(ClipStorageConstants.isSubscriber, isFalse);
    expect(ClipStorageConstants.isServerStorageLocked, isTrue,
        reason: '유료화 전 기본 잠금은 그대로다');
  });

  test('구독하면 잠금이 풀린다', () async {
    await _provider(tier: 'light');

    expect(ClipStorageConstants.isSubscriber, isTrue);
  });

  test('무료로 돌아가면 다시 잠근다', () async {
    await _provider(tier: 'pro');
    expect(ClipStorageConstants.isSubscriber, isTrue);

    await _provider(tier: 'free');
    expect(ClipStorageConstants.isSubscriber, isFalse);
  });

  test('구독 중이면 서버 저장을 잠그지 않는다', () {
    ClipStorageConstants.isSubscriber = true;

    expect(ClipStorageConstants.isServerStorageLockedForCurrentUser(), isFalse);
  });
}
