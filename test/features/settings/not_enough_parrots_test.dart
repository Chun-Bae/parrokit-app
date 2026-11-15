// 패롯이 모자랄 때 뜨는 안내. 무엇이 모자란지와 할 수 있는 일을 보여 준다.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/settings/subscription/presentation/not_enough_parrots_sheet.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

class _FakePaywall implements PaywallPresenter {
  int shown = 0;

  @override
  Future<void> show(BuildContext context) async => shown++;
}

Future<SubscriptionProvider> _subscription(
  WidgetTester tester, {
  required String tier,
}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('uid-1').set({
    'subscription': {'tier': tier, 'status': 'active'},
  });
  final provider = SubscriptionProvider(firestore: db);
  addTearDown(provider.dispose);
  provider.syncUser('uid-1');
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)));
  return provider;
}

Future<void> _open(
  WidgetTester tester, {
  required SubscriptionProvider subscription,
  _FakePaywall? paywall,
  int needed = 5,
  int have = 4,
}) async {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  await tester.pumpWidget(ChangeNotifierProvider<SubscriptionProvider>.value(
    value: subscription,
    child: MaterialApp(
      theme:
          ThemeData(colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
      home: Scaffold(
        body: NotEnoughParrotsSheet(
            needed: needed, have: have, presenter: paywall),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('본문은 얼마가 필요하고 얼마가 있는지 적는다', () {
    expect(notEnoughParrotsBody(needed: 5, have: 4), '이번 작업에 5개가 필요한데 4개가 있어요.');
    expect(notEnoughParrotsTitle, '패롯이 모자라요');
  });

  testWidgets('무료에게는 구독 보기를 보여 준다', (tester) async {
    final subscription = await _subscription(tester, tier: 'free');
    await _open(tester, subscription: subscription);

    expect(find.text(notEnoughParrotsTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('not-enough-body')), findsOneWidget);
    expect(find.text(subscriptionOpenButtonLabel), findsOneWidget);
    expect(find.textContaining('광고'), findsWidgets, reason: '광고로 받는 길도 있다');
  });

  testWidgets('구독자에게는 구독 보기를 보여 주지 않는다', (tester) async {
    final subscription = await _subscription(tester, tier: 'pro');
    await _open(tester, subscription: subscription);

    expect(find.byKey(const ValueKey('not-enough-subscribe')), findsNothing);
  });

  testWidgets('구독 보기를 누르면 구독 화면으로 간다', (tester) async {
    final subscription = await _subscription(tester, tier: 'free');
    final paywall = _FakePaywall();
    await _open(tester, subscription: subscription, paywall: paywall);

    await tester.tap(find.byKey(const ValueKey('not-enough-subscribe')));
    await tester.pump();

    expect(paywall.shown, 1);
  });
}
