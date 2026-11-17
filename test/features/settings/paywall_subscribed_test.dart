// 구독 화면을 띄울지 가르는 기준(5차 459).
//
// 전에는 RevenueCatPaywallPresenter가
// presentPaywallIfNeeded(IapProvider.entitlementId)를 불렀다. 그 값은
// 광고 제거(1회 구매) entitlement라, 구독한 사람에게도 Paywall이 뜨고
// 광고 제거만 산 사람에게는 안 떴다.

import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_state.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

const _path =
    'lib/features/settings/subscription/presentation/paywall_presenter.dart';

String _code() => File(_path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('///'))
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

Future<bool> _ask(
  WidgetTester tester, {
  String? tier,
  Set<String> entitlements = const {},
}) async {
  final store = FakeFirebaseFirestore();
  if (tier != null) {
    await store.collection('users').doc('uid-1').set({
      'subscription': {'tier': tier, 'status': 'active'},
    });
  }
  final subscription = SubscriptionProvider(firestore: store);
  addTearDown(subscription.dispose);
  subscription.syncUser('uid-1');
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)));

  final iap = IapProvider();
  addTearDown(iap.dispose);
  iap.activeEntitlements = entitlements;

  late bool answer;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SubscriptionProvider>.value(value: subscription),
      ChangeNotifierProvider<IapProvider>.value(value: iap),
    ],
    child: MaterialApp(
      home: Builder(builder: (context) {
        answer = isSubscribedNow(context);
        return const SizedBox();
      }),
    ),
  ));
  return answer;
}

void main() {
  testWidgets('무료면 구독 중이 아니다', (tester) async {
    expect(await _ask(tester, tier: 'free'), isFalse);
  });

  testWidgets('서버가 적어 준 단계가 있으면 구독 중이다', (tester) async {
    expect(await _ask(tester, tier: 'light'), isTrue);
    expect(await _ask(tester, tier: 'pro'), isTrue);
  });

  testWidgets('서버가 아직 안 적었으면 RevenueCat entitlement로 본다', (tester) async {
    expect(
        await _ask(tester, entitlements: {lightEntitlementId}), isTrue);
    expect(await _ask(tester, entitlements: {proEntitlementId}), isTrue);
  });

  testWidgets('광고 제거만 산 사람은 구독 중이 아니다', (tester) async {
    // 이것이 전에 섞여 있던 부분이다.
    expect(
        await _ask(tester, entitlements: {IapProvider.entitlementId}), isFalse);
  });

  test('구독 화면을 광고 제거 entitlement로 가르지 않는다', () {
    final code = _code();
    expect(code.contains('presentPaywallIfNeeded(IapProvider.entitlementId)'),
        isFalse);
    expect(code, contains('isSubscribedNow(context)'));
  });

  test('구독 화면을 띄울 offering을 짚어 준다(5차 461)', () {
    // 그냥 presentPaywall()을 부르면 기본 offering이 뜬다. 이 프로젝트의
    // 기본은 광고 제거라, 구독을 눌렀는데 '평생 광고 제거'가 떴다.
    expect(subscriptionOfferingId, 'parrokit_subscription');
    final code = _code();
    expect(code, contains('offerings.all[subscriptionOfferingId]'));
    expect(code, contains('RevenueCatUI.presentPaywall(offering: offering)'));
    // 그 offering이 없으면 엉뚱한 화면을 띄우지 않고 까닭을 말한다.
    expect(code, contains('if (offering == null)'));
  });
}
