// 무료 사용자에게만 '이 기기에만 있어요'를 알린다(5차 5단계).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/local_only_notice.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _open(
  WidgetTester tester, {
  required SubscriptionTier tier,
  int localOnlyCount = 3,
  VoidCallback? onBackup,
  VoidCallback? onSubscribe,
}) async {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  await tester.pumpWidget(MaterialApp(
    theme:
        ThemeData(colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
    home: Scaffold(
      body: LocalOnlyNotice(
        tier: tier,
        localOnlyCount: localOnlyCount,
        onBackup: onBackup ?? () {},
        onSubscribe: onSubscribe ?? () {},
      ),
    ),
  ));
  // 오늘 닫았는지 먼저 읽고 그린다. 한 번 더 돌려 그 답을 받는다.
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('무료이고 클립이 있을 때만 보여 준다', () {
    expect(
        showsLocalOnlyNotice(tier: SubscriptionTier.free, localOnlyCount: 1), isTrue);
    expect(showsLocalOnlyNotice(tier: SubscriptionTier.free, localOnlyCount: 0),
        isFalse,
        reason: '이 기기에만 있는 클립이 없으면 알릴 것도 없다');
    expect(showsLocalOnlyNotice(tier: SubscriptionTier.light, localOnlyCount: 5),
        isFalse,
        reason: '구독하면 서버에 올라간다');
    expect(
        showsLocalOnlyNotice(tier: SubscriptionTier.pro, localOnlyCount: 5), isFalse);
  });

  testWidgets('무엇이 문제이고 무엇을 할 수 있는지 함께 적는다', (tester) async {
    await _open(tester, tier: SubscriptionTier.free);

    expect(find.text(localOnlyNoticeTitle), findsOneWidget);
    // 몇 개가 사라지는지 적는다. 서버에 올라간 클립은 세지 않는다.
    expect(find.text(localOnlyNoticeBody(3)), findsOneWidget);
    // 폴더 안에서도 같은 안내가 뜨므로 무엇을 센 수인지 적는다(5차 484).
    expect(find.textContaining('보관함의 클립 3개가 사라져요'), findsOneWidget);
    expect(find.text(localOnlyBackupLabel), findsOneWidget);
    expect(find.text(localOnlySubscribeLabel), findsOneWidget);
  });

  testWidgets('구독자에게는 아무것도 보이지 않는다', (tester) async {
    await _open(tester, tier: SubscriptionTier.pro);

    expect(find.byKey(const ValueKey('local-only-notice')), findsNothing);
  });

  testWidgets('두 버튼이 각각 제 일을 부른다', (tester) async {
    var backups = 0;
    var subscribes = 0;
    await _open(tester,
        tier: SubscriptionTier.free,
        onBackup: () => backups++,
        onSubscribe: () => subscribes++);

    await tester.tap(find.byKey(const ValueKey('local-only-backup')));
    await tester.tap(find.byKey(const ValueKey('local-only-subscribe')));
    await tester.pump();

    expect(backups, 1);
    expect(subscribes, 1);
  });

  // 보관함을 열 때마다 같은 띠가 버티고 있으면 성가시다. 닫으면 그날은
  // 쉬고 다음 날 다시 한 번 알린다(5차 565, 사용자 요청).
  testWidgets('닫으면 사라지고 오늘 날짜를 적어 둔다', (tester) async {
    await _open(tester, tier: SubscriptionTier.free);
    expect(find.byKey(const ValueKey('local-only-notice')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('local-only-dismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('local-only-notice')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocalOnlyNoticeDismissal.key),
        LocalOnlyNoticeDismissal.dayOf(DateTime.now()));
  });

  testWidgets('오늘 닫았으면 다시 열어도 안 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({
      LocalOnlyNoticeDismissal.key:
          LocalOnlyNoticeDismissal.dayOf(DateTime.now()),
    });

    await _open(tester, tier: SubscriptionTier.free);

    expect(find.byKey(const ValueKey('local-only-notice')), findsNothing);
  });

  testWidgets('어제 닫았으면 오늘은 다시 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({
      LocalOnlyNoticeDismissal.key: LocalOnlyNoticeDismissal.dayOf(
          DateTime.now().subtract(const Duration(days: 1))),
    });

    await _open(tester, tier: SubscriptionTier.free);

    expect(find.byKey(const ValueKey('local-only-notice')), findsOneWidget);
  });

  test('날은 한국 자정으로 가른다', () {
    // 한국 9시는 UTC 0시다. 같은 한국 날짜면 같은 값이어야 한다.
    final morningKst = DateTime.utc(2026, 11, 22, 0, 30);
    final eveningKst = DateTime.utc(2026, 11, 22, 14, 30);
    expect(LocalOnlyNoticeDismissal.dayOf(morningKst),
        LocalOnlyNoticeDismissal.dayOf(eveningKst));
    // 한국 자정을 넘기면 다른 날이다(UTC 15시 = 한국 다음 날 0시).
    expect(LocalOnlyNoticeDismissal.dayOf(DateTime.utc(2026, 11, 22, 15, 1)),
        isNot(LocalOnlyNoticeDismissal.dayOf(morningKst)));
  });
}
