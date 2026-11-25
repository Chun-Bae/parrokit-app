// 시트에서 누른 일의 결과가 보여야 한다(5차).
//
// 복원·구독 열기는 결과를 토스트로 알린다. 토스트는 화면의 Scaffold가 그리는
// SnackBar라 **시트 뒤 맨 아래**에 깔린다. 시트를 열어 둔 채로 띄우면
// 사용자 눈에는 아무 일도 안 일어난 것으로 보인다.
//
// 시뮬레이터에서 더보기 > 저장 용량 > '구독 보기' > '이미 구독했다면 구매 복원'을
// 눌러 찾았다. 로그에는 '[🍞] 복원할 구독을 찾지 못했어요.'가 남았는데 화면에는
// 아무것도 안 떴다 - 저장 용량 시트가 그대로 떠 있었기 때문이다.
//
// 그래서 두 시트 모두 **닫고 나서** 한다.

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/settings/more/presentation/sections/remote_storage_section.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_status_sheet.dart';

class _FakePaywall implements PaywallPresenter {
  int shown = 0;

  @override
  Future<void> show(BuildContext context) async => shown++;
}

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  @override
  AppUser? get currentUser => AppUser(id: 'uid-1', parrots: 3, subParrots: 10);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  testWidgets('저장 용량 시트의 구독 보기는 시트를 닫고 연다', (tester) async {
    final subscription = await _subscription(tester, tier: 'free');
    final paywall = _FakePaywall();
    final cs = ColorScheme.fromSeed(seedColor: Colors.blue);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ClipProvider>.value(value: clipProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(value: subscription),
      ],
      child: MaterialApp(
        // 시트를 닫은 뒤 구독 화면을 여는 곳이 여기다.
        navigatorKey: rootNavigatorKey,
        theme: ThemeData(
            colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => RemoteStorageDetails(
                  presenter: paywall,
                  readCacheBytes: () async => 0,
                ),
              ),
              child: const Text('저장 용량'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('저장 용량'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('storage-open-subscription')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('storage-open-subscription')));
    await tester.pumpAndSettle();

    // 시트가 닫혀야 뒤에 깔리는 토스트가 보인다.
    expect(find.byKey(const ValueKey('storage-open-subscription')), findsNothing,
        reason: '시트를 닫는다');
    expect(paywall.shown, 1, reason: '닫은 뒤에도 구독 화면은 연다');
  });

  testWidgets('구독 상태 시트의 복원·관리는 시트를 닫고 한다', (tester) async {
    final subscription = await _subscription(tester, tier: 'pro');
    var restored = 0;
    var managed = 0;
    final cs = ColorScheme.fromSeed(seedColor: Colors.blue);

    Future<void> open() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionProvider>.value(
              value: subscription),
          ChangeNotifierProvider<UserProvider>(
              create: (_) => _FakeUserProvider()),
        ],
        child: MaterialApp(
          theme: ThemeData(
              colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => SubscriptionStatusSheet(
                    onRestore: () => restored++,
                    onManage: () => managed++,
                  ),
                ),
                child: const Text('구독'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('구독'));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.tap(find.byKey(const ValueKey('status-restore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-restore')), findsNothing,
        reason: '복원 결과 토스트가 시트 뒤에 가리면 안 된다');
    expect(restored, 1);

    await open();
    await tester.tap(find.byKey(const ValueKey('status-manage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-manage')), findsNothing);
    expect(managed, 1);
  });
}
