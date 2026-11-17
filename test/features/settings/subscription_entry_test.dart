// 구독 줄과 미리보기 화면. 스토어 상품이 없어도 화면이 열리고, 심사가
// 요구하는 안내가 빠지지 않아야 한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_preview_sheet.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

Widget _wrap(Widget child) {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  return MaterialApp(
    theme: ThemeData(
      colorScheme: cs,
      textTheme: appTextTheme(cs, isDark: false),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('단계 이름', () {
    test('이름과 부제가 단계에 맞는다', () {
      expect(subscriptionTierName(SubscriptionTier.free), '무료');
      expect(subscriptionTierName(SubscriptionTier.light), '라이트');
      expect(subscriptionTierName(SubscriptionTier.pro), '프로');
      expect(subscriptionRowSubtitle(SubscriptionTier.free),
          '광고 없이, 매달 패롯을 받아요.');
      expect(subscriptionRowSubtitle(SubscriptionTier.pro), contains('구독 중'));
    });

    test('광고는 무료이면서 1회 구매도 없을 때만 보여 준다', () {
      expect(showsAds(tier: SubscriptionTier.free, adsRemoved: false), isTrue);
      expect(showsAds(tier: SubscriptionTier.free, adsRemoved: true), isFalse);
      expect(showsAds(tier: SubscriptionTier.light, adsRemoved: false), isFalse);
    });
  });

  group('Paywall 고르기', () {
    test('출시 빌드는 늘 진짜 Paywall', () {
      expect(usesRealPaywall(releaseMode: true, realPaywallFlag: false), isTrue);
      expect(
          resolvePaywallPresenter(releaseMode: true, realPaywallFlag: false),
          isA<RevenueCatPaywallPresenter>());
    });

    test('개발 빌드는 미리보기, 깃발을 켜면 진짜', () {
      expect(
          resolvePaywallPresenter(releaseMode: false, realPaywallFlag: false),
          isA<PreviewPaywallPresenter>());
      expect(resolvePaywallPresenter(releaseMode: false, realPaywallFlag: true),
          isA<RevenueCatPaywallPresenter>());
    });
  });

  group('미리보기 화면', () {
    testWidgets('두 단계와 혜택, 값을 보여 준다', (tester) async {
      await tester.pumpWidget(_wrap(const SubscriptionPreviewSheet()));

      expect(find.text('라이트'), findsOneWidget);
      expect(find.text('프로'), findsOneWidget);
      expect(find.text('월 ₩2,900'), findsOneWidget);
      expect(find.text('매달 패롯 100개'), findsOneWidget);
      expect(find.text('서버 백업 30GB'), findsOneWidget);
      expect(find.text('라이트 시작하기'), findsOneWidget);
    });

    testWidgets('심사가 요구하는 안내가 빠지지 않는다', (tester) async {
      await tester.pumpWidget(_wrap(const SubscriptionPreviewSheet()));

      expect(find.text(subscriptionRenewalNotice), findsOneWidget);
      expect(find.text(subscriptionParrotNotice), findsOneWidget);
      expect(find.text(subscriptionRestoreLabel), findsOneWidget);
    });

    testWidgets('미리보기라는 것을 숨기지 않는다', (tester) async {
      await tester.pumpWidget(_wrap(const SubscriptionPreviewSheet()));
      expect(find.byKey(const ValueKey('subscription-preview-notice')),
          findsOneWidget);
    });

    testWidgets('살 수 없으니 눌리지도 않는다(5차 448)', (tester) async {
      // 370에서는 누른 뒤 까닭을 시트 안에 적었다. 그래도 파란 버튼이라
      // 살 수 있어 보였다. 이제 눌리지 않고, 까닭은 누르기 전에 보인다.
      await tester.pumpWidget(_wrap(const SubscriptionPreviewSheet()));

      for (final key in ['start-light', 'start-pro']) {
        final button = tester.widget<FilledButton>(
            find.byKey(ValueKey(key), skipOffstage: false));
        expect(button.onPressed, isNull, reason: key);
      }
      final restore = tester.widget<TextButton>(
          find.byKey(const ValueKey('subscription-restore'),
              skipOffstage: false));
      expect(restore.onPressed, isNull);
    });

    testWidgets('준비 중이라는 안내가 단계 카드보다 위에 있다(5차 448)', (tester) async {
      await tester.pumpWidget(_wrap(const SubscriptionPreviewSheet()));

      final notice = tester.getTopLeft(
          find.byKey(const ValueKey('subscription-preview-notice')));
      final firstCard = tester.getTopLeft(
          find.byKey(const ValueKey('start-light'), skipOffstage: false));
      expect(notice.dy, lessThan(firstCard.dy));
    });

    testWidgets('눌리지 않아도 무엇이 생길지는 보인다', (tester) async {
      await tester.pumpWidget(_wrap(const SubscriptionPreviewSheet()));
      expect(find.text('라이트 시작하기'), findsOneWidget);
      expect(find.text('프로 시작하기'), findsOneWidget);
      expect(find.text(subscriptionRestoreLabel), findsOneWidget);
    });

    test('안내 글이 앱 말투다', () {
      for (final text in [
        subscriptionFreeBody,
        subscriptionRenewalNotice,
        subscriptionParrotNotice,
        subscriptionNotReadyToast,
        subscriptionPreviewNotice,
      ]) {
        expect(text, isNot(contains('습니다')), reason: text);
      }
    });
  });
}
