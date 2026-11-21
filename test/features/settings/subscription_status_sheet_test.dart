// 구독 중 화면: 지금 단계, 다음 결제일, 남은 패롯과 서버 백업, 상태별 안내.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_quota.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_state.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_status_sheet.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  _FakeUserProvider({this.subParrots = 0});

  final int subParrots;

  @override
  AppUser? get currentUser =>
      AppUser(id: 'uid-1', parrots: 3, subParrots: subParrots);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<SubscriptionProvider> _subscription(
  WidgetTester tester, {
  required String tier,
  required String status,
  int? periodEndMs,
  int? storageBytes,
}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('uid-1').set({
    'subscription': {
      'tier': tier,
      'status': status,
      if (periodEndMs != null) 'periodEnd': periodEndMs,
    },
    if (storageBytes != null) 'storage': {'usedBytes': storageBytes},
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
  int subParrots = 0,
  VoidCallback? onUpgrade,
}) async {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SubscriptionProvider>.value(value: subscription),
      ChangeNotifierProvider<UserProvider>(
          create: (_) => _FakeUserProvider(subParrots: subParrots)),
    ],
    child: MaterialApp(
      theme: ThemeData(
          colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
      home: Scaffold(
          body: SubscriptionStatusSheet(onUpgrade: onUpgrade)),
    ),
  ));
  await tester.pump();
}

void main() {
  test('단계마다 매달 받는 패롯이 구독 화면에 적은 수와 같다', () {
    expect(monthlyParrotsFor(SubscriptionTier.light), 100);
    expect(monthlyParrotsFor(SubscriptionTier.pro), 400);
    expect(monthlyParrotsFor(SubscriptionTier.free), 0);
  });

  test('남은 양은 쓴 양이 아니라 남은 양으로 적는다', () {
    expect(subscriptionRemainingText(62, 100), '62 / 100 남음');
  });

  test('상태별 안내는 그 상태일 때만 나온다', () {
    final end = DateTime(2026, 12, 15);
    expect(subscriptionStatusNotice(SubscriptionStatus.active, end), isNull);
    expect(subscriptionStatusNotice(SubscriptionStatus.grace, end),
        contains('결제가 밀렸어요'));
    expect(subscriptionStatusNotice(SubscriptionStatus.canceled, end),
        '12월 15일에 끝나요. 그때까지는 그대로 쓸 수 있어요.');
    expect(subscriptionStatusNotice(SubscriptionStatus.expired, end),
        contains('기기에 남아 있어요'));
  });

  testWidgets('라이트는 단계·다음 결제일·남은 패롯·백업을 보여 준다', (tester) async {
    final end = DateTime(2026, 12, 15);
    final subscription = await _subscription(tester,
        tier: 'light',
        status: 'active',
        periodEndMs: end.millisecondsSinceEpoch,
        storageBytes: 1024 * 1024 * 1024);
    await _open(tester, subscription: subscription, subParrots: 62);

    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('다음 결제일 12월 15일'), findsOneWidget);
    expect(find.text(subscriptionParrotRowTitle), findsOneWidget);
    expect(find.text(subscriptionStorageRowTitle), findsOneWidget);
    expect(find.text('62 / 100 남음'), findsOneWidget);
    expect(find.textContaining('1.0 GB / 10 GB'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-notice')), findsNothing);
  });

  testWidgets('맥스가 아니면 올리기를 보여 준다', (tester) async {
    final light = await _subscription(tester, tier: 'light', status: 'active');
    await _open(tester, subscription: light, onUpgrade: () {});
    expect(find.byKey(const ValueKey('status-upgrade')), findsOneWidget);

    final pro = await _subscription(tester, tier: 'pro', status: 'active');
    await _open(tester, subscription: pro, onUpgrade: () {});
    expect(find.byKey(const ValueKey('status-upgrade')), findsOneWidget);
    expect(find.text('프로'), findsOneWidget);
    expect(find.text('400 남음'), findsNothing);

    final max = await _subscription(tester, tier: 'max', status: 'active');
    await _open(tester, subscription: max, onUpgrade: () {});
    expect(find.byKey(const ValueKey('status-upgrade')), findsNothing);
    expect(find.text('맥스'), findsOneWidget);
  });

  testWidgets('올리기 단추가 자기 단계를 가리키지 않는다', (tester) async {
    // '프로로 올리기'로 박혀 있어서 프로를 쓰는 사람도 프로를 권유받았다(5차 520).
    for (final name in ['light', 'plus', 'pro']) {
      final sub = await _subscription(tester, tier: name, status: 'active');
      await _open(tester, subscription: sub, onUpgrade: () {});
      final label = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('status-upgrade')),
        matching: find.byType(Text),
      ));
      expect(label.data, subscriptionUpgradeLabel);
      for (final tier in SubscriptionTier.values) {
        expect(subscriptionUpgradeLabel.contains(subscriptionTierName(tier)),
            isFalse,
            reason: '올리기 단추에 단계 이름을 박으면 다른 단계에서 틀린 말이 된다');
      }
    }
  });

  testWidgets('해지를 예약하면 언제 끝나는지 알린다', (tester) async {
    final end = DateTime(2026, 12, 15);
    final subscription = await _subscription(tester,
        tier: 'pro',
        status: 'canceled',
        periodEndMs: end.millisecondsSinceEpoch);
    await _open(tester, subscription: subscription);

    expect(find.byKey(const ValueKey('status-notice')), findsOneWidget);
    expect(find.textContaining('12월 15일에 끝나요'), findsOneWidget);
  });

  testWidgets('심사가 요구하는 안내와 관리·복원 버튼이 있다', (tester) async {
    final subscription = await _subscription(tester, tier: 'pro', status: 'active');
    await _open(tester, subscription: subscription);

    expect(find.text(subscriptionManageLabel), findsOneWidget);
    expect(find.text(subscriptionRestoreButtonLabel), findsOneWidget);
    expect(find.text(subscriptionRenewalNotice), findsOneWidget);
    expect(find.text(subscriptionParrotNotice), findsOneWidget);
  });
}
