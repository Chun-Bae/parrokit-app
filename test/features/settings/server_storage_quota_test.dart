// 서버 저장 용량을 단계가 정하고, 센 값은 서버가 준다.

import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_quota.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

const int gb = 1024 * 1024 * 1024;

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('단계별 한도는 서버(storageUsage.ts)와 같다', () {
    expect(serverStorageQuotaBytes(SubscriptionTier.free), 0);
    expect(serverStorageQuotaBytes(SubscriptionTier.light), 10 * gb);
    expect(serverStorageQuotaBytes(SubscriptionTier.plus), 20 * gb);
    expect(serverStorageQuotaBytes(SubscriptionTier.pro), 30 * gb);
    expect(serverStorageQuotaBytes(SubscriptionTier.max), 80 * gb);
  });

  test('서버 저장 막대를 그리는 곳은 모두 단계별 한도를 쓴다', () {
    // 예전 보관함 화면은 1GB를 박아 둬서, 라이트(5GB) 구독자가 2GB만 써도
    // '가득 찼다'고 했다(5차).
    for (final path in [
      'lib/features/collection/library/presentation/sections/library_folder_section.dart',
      'lib/features/settings/more/presentation/sections/remote_storage_section.dart',
    ]) {
      final code = File(path).readAsStringSync();
      expect(code, contains('serverStorageQuotaBytes('), reason: path);
    }
    // 박아 둔 상수는 지웠다.
    final provider =
        File('lib/core/state/provider/clip_provider.dart').readAsStringSync();
    expect(provider.contains('static const int serverStorageQuotaBytes'),
        isFalse);
  });

  test('무료에게는 서버에 담을 곳이 없다는 것을 먼저 알린다', () {
    expect(serverStorageSubtitle(SubscriptionTier.free), contains('구독하면'));
    expect(serverStorageSubtitle(SubscriptionTier.pro), isNot(contains('구독하면')));
  });

  test('서버가 센 용량을 읽는다', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('uid-1').set({
      'storage': {'usedBytes': 2048, 'objectCount': 3},
      'subscription': {'tier': 'light', 'status': 'active'},
    });
    final provider = SubscriptionProvider(firestore: db);
    addTearDown(provider.dispose);

    provider.syncUser('uid-1');
    await settle();

    expect(provider.storageUsedBytes, 2048);
    expect(provider.tier, SubscriptionTier.light);
  });

  test('서버가 아직 안 센 사람은 null이고, 로그아웃하면 지운다', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('uid-1').set({'nickname': '춘배'});
    final provider = SubscriptionProvider(firestore: db);
    addTearDown(provider.dispose);

    provider.syncUser('uid-1');
    await settle();
    expect(provider.storageUsedBytes, isNull);

    await db.collection('users').doc('uid-1').set({
      'storage': {'usedBytes': 10},
    });
    await settle();
    expect(provider.storageUsedBytes, 10);

    provider.syncUser(null);
    await settle();
    expect(provider.storageUsedBytes, isNull);
  });
}
