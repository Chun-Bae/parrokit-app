// 더보기 > 저장 용량 시트의 서버 칸(5차 449).
//
// 무료는 서버에 담을 곳이 0인데도 빈 진행 막대를 그렸고('아직 안 찼다'로
// 읽힌다), '구독하면 영상이 서버에 백업돼요'라고만 하고 갈 길이 없었다.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/features/settings/more/presentation/sections/remote_storage_section.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

class _FakePaywall implements PaywallPresenter {
  int shown = 0;

  @override
  Future<void> show(BuildContext context) async => shown++;
}

void main() {
  late AppDatabase db;
  late ClipProvider clipProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    clipProvider = ClipProvider(db);
  });

  tearDown(() async {
    clipProvider.dispose();
    await db.close();
  });

  Future<_FakePaywall> open(
    WidgetTester tester, {
    required String tier,
    int cacheBytes = 0,
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

    final paywall = _FakePaywall();
    final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ClipProvider>.value(value: clipProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(value: subscription),
      ],
      child: MaterialApp(
        theme: ThemeData(
            colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
        home: Scaffold(
          body: RemoteStorageDetails(
            presenter: paywall,
            readCacheBytes: () async => cacheBytes,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return paywall;
  }

  testWidgets('무료에게는 채울 수 없는 막대를 그리지 않는다', (tester) async {
    await open(tester, tier: 'free');
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('무료에게는 구독으로 가는 길을 준다', (tester) async {
    final paywall = await open(tester, tier: 'free');
    expect(find.text(subscriptionOpenButtonLabel), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('storage-open-subscription')));
    await tester.pump();
    expect(paywall.shown, 1);
  });

  testWidgets('구독 중이면 한도 막대를 보여 주고 권하지 않는다', (tester) async {
    await open(tester, tier: 'light');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('storage-open-subscription')),
        findsNothing);
  });

  testWidgets('기기 칸이 임시 파일까지 더해서 보여 준다(5차 450)', (tester) async {
    // 전에는 보관한 영상만 세어서, 바로 옆 '임시 파일' 칸과 숫자가 달랐다.
    await open(tester, tier: 'free', cacheBytes: 2 * 1024 * 1024);

    expect(find.text('2.0 MB'), findsOneWidget, reason: '기기 합계');
    expect(find.text('임시 파일 2.0 MB'), findsOneWidget);
    expect(find.text('보관한 영상 0 B'), findsOneWidget);
    expect(find.text('받아 둔 영상 0 B'), findsOneWidget);
  });

  testWidgets('임시 파일을 아직 못 읽었으면 세는 중이라고 말한다', (tester) async {
    final store = FakeFirebaseFirestore();
    final subscription = SubscriptionProvider(firestore: store);
    addTearDown(subscription.dispose);
    final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ClipProvider>.value(value: clipProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(value: subscription),
      ],
      child: MaterialApp(
        theme: ThemeData(
            colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
        home: Scaffold(
          body: RemoteStorageDetails(
            readCacheBytes: () => Completer<int>().future,
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('임시 파일 세는 중'), findsOneWidget);
  });
}
