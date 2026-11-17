// 더보기의 '광고 제거' 줄(5차 463).
//
// 광고 제거는 한 번 사는 상품이라 구독과 다른데, 더보기에 입구가 아예
// 없었다(PaymentSection은 어느 화면도 쓰지 않는 죽은 코드였다).
// 구독에는 '광고 없이'가 들어 있어서, 구독 중인 사람이 또 사면 돈만 버린다.

import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/settings/more/presentation/sections/ads_removal_section.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

Future<int> _open(
  WidgetTester tester, {
  required String tier,
  required bool owned,
}) async {
  final store = FakeFirebaseFirestore();
  await store.collection('users').doc('uid-1').set({
    'subscription': {'tier': tier, 'status': 'active'},
  });
  final subscription = SubscriptionProvider(firestore: store);
  addTearDown(subscription.dispose);
  subscription.syncUser('uid-1');
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)));

  final iap = IapProvider();
  addTearDown(iap.dispose);
  iap.isPremium = owned;

  var taps = 0;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SubscriptionProvider>.value(value: subscription),
      ChangeNotifierProvider<IapProvider>.value(value: iap),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: AdsRemovalSection(onBuy: (_) async => taps++),
      ),
    ),
  ));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('ads-removal-row')));
  await tester.pump();
  return taps;
}

void main() {
  test('상태 셋을 한 곳에서 고른다', () {
    expect(adsRemovalSubtitle(subscribed: false, owned: false),
        '한 번 사면 쇼츠 광고가 사라져요.');
    expect(adsRemovalSubtitle(subscribed: false, owned: true), '광고를 지웠어요.');
    // 구독이 먼저다. 구독 중이면 산 적이 있든 없든 들어 있다고 말한다.
    expect(adsRemovalSubtitle(subscribed: true, owned: false), '구독에 들어 있어요.');
    expect(adsRemovalSubtitle(subscribed: true, owned: true), '구독에 들어 있어요.');
  });

  test('오른쪽 상태 글이 구독 줄과 같은 꼴이다', () {
    expect(adsRemovalStateLabel(subscribed: false, owned: false), '꺼짐');
    expect(adsRemovalStateLabel(subscribed: false, owned: true), '켜짐');
    expect(adsRemovalStateLabel(subscribed: true, owned: false), '구독 포함');
  });

  testWidgets('안 샀으면 눌러서 살 수 있다', (tester) async {
    expect(await _open(tester, tier: 'free', owned: false), 1);
  });

  testWidgets('이미 샀으면 또 사게 두지 않는다', (tester) async {
    expect(await _open(tester, tier: 'free', owned: true), 0);
  });

  testWidgets('구독 중이면 또 사게 두지 않는다', (tester) async {
    // 구독에 '광고 없이'가 들어 있다. 또 사면 돈만 버린다.
    expect(await _open(tester, tier: 'light', owned: false), 0);
  });

  test('더보기 화면이 구독 줄 바로 아래에 둔다', () {
    final code =
        File('lib/features/settings/more/presentation/more_screen.dart')
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
    final sub = code.indexOf('SubscriptionSection()');
    final ads = code.indexOf('AdsRemovalSection()');
    expect(sub, greaterThan(-1));
    expect(ads, greaterThan(sub));
  });

  test('어느 화면을 띄울지 짚어 준다', () {
    expect(adsRemovalOfferingId, 'parrokit_ads_removed');
    final code = File(
            'lib/features/settings/more/presentation/sections/ads_removal_section.dart')
        .readAsStringSync();
    expect(code, contains('offerings.all[adsRemovalOfferingId]'));
    expect(code, contains('RevenueCatUI.presentPaywall(offering: offering)'));
  });
}
