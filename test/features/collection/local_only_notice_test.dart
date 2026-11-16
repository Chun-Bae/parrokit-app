// 무료 사용자에게만 '이 기기에만 있어요'를 알린다(5차 5단계).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/local_only_notice.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

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
  await tester.pump();
}

void main() {
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
    expect(find.textContaining('클립 3개가 사라져요'), findsOneWidget);
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
}
