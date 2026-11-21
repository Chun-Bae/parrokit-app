// 구독 중이어도 올라갈 자리가 있으면 Paywall이 떠야 한다(5차 548).
//
// 단계가 넷이 된 뒤에도 RevenueCatPaywallPresenter.show는 첫 줄에서
// '구독 중이면 돌아간다'로 막고 있었다. 구독 칸의 '올리기'가 바로 이
// show를 부르므로, 출시 빌드에서 라이트 사용자가 플러스·프로·맥스로
// 올라갈 길이 아예 없었다.

import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

Future<SubscriptionTier> tierSeenBy(
  WidgetTester tester,
  String? serverTier,
) async {
  final db = FakeFirebaseFirestore();
  if (serverTier != null) {
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': serverTier, 'status': 'active'},
    });
  } else {
    await db.collection('users').doc('uid-1').set({'nickname': '춘배'});
  }
  final provider = SubscriptionProvider(firestore: db);
  addTearDown(provider.dispose);
  provider.syncUser('uid-1');
  await tester.pump(const Duration(milliseconds: 20));

  late SubscriptionTier seen;
  await tester.pumpWidget(ChangeNotifierProvider<SubscriptionProvider>.value(
    value: provider,
    child: MaterialApp(
      home: Builder(builder: (context) {
        seen = currentTierNow(context);
        return const SizedBox();
      }),
    ),
  ));
  return seen;
}

void main() {
  testWidgets('지금 단계를 서버 값에서 읽는다', (tester) async {
    expect(await tierSeenBy(tester, 'light'), SubscriptionTier.light);
    expect(await tierSeenBy(tester, 'max'), SubscriptionTier.max);
    expect(await tierSeenBy(tester, null), SubscriptionTier.free);
  });

  test('맨 위가 아니면 올라갈 자리가 있다', () {
    expect(isTopTier(SubscriptionTier.light), isFalse);
    expect(isTopTier(SubscriptionTier.plus), isFalse);
    expect(isTopTier(SubscriptionTier.pro), isFalse);
    expect(isTopTier(SubscriptionTier.max), isTrue);
  });

  test('구독 중이라고 막지 않는다', () {
    // show()가 isSubscribedNow로 막으면 올리기가 통째로 죽는다. 다시
    // 그렇게 되지 않게 소스에서 본다.
    final src = File(
      'lib/features/settings/subscription/presentation/paywall_presenter.dart',
    ).readAsStringSync();
    final body = src.substring(src.indexOf('Future<void> show('));
    final guard = body.substring(0, body.indexOf('PaywallResult result;'));
    expect(guard.contains('isTopTier('), isTrue,
        reason: '맨 위 단계일 때만 막아야 한다');
    expect(guard.contains('isSubscribedNow('), isFalse,
        reason: '구독 중이라는 것만으로 막으면 올리기가 죽는다');
  });
}
