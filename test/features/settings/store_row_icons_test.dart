// 상품 줄(구독·광고 제거)의 그림이 실제로 있는 파일을 가리키는지 본다(5차 465).
//
// 경로를 잘못 적으면 화면에서 그림만 조용히 안 뜬다. analyze도 테스트도
// 잡아 주지 않아, 기기를 봐야만 알 수 있었다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/leading_icon.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/shared/store_badges.dart';

void main() {
  test('그림 파일을 가리키는 배지는 그 파일이 있다', () {
    for (final badge in storeBadges) {
      final asset = badge.asset;
      if (asset == null) continue;
      expect(File(asset).existsSync(), isTrue, reason: '$asset 가 없다');
    }
  });

  test('상품 그림 목록이 서로 다른 심볼과 색을 쓴다', () {
    expect(storeBadges.map((b) => b.name).toSet().length, storeBadges.length);
    expect(storeBadges.map((b) => b.icon).toSet().length, storeBadges.length,
        reason: '상품마다 심볼이 달라야 한다');
    for (final badge in storeBadges) {
      expect(badge.colors.length, 2, reason: '${badge.name}: 그라데이션은 두 색이다');
    }
  });

  test('구독 단계마다 그 목록 안의 다른 배지를 쓴다', () {
    final badges =
        SubscriptionTier.values.map(subscriptionTierBadgeOf).toList();
    expect(badges.map((b) => b.icon).toSet().length, badges.length,
        reason: '단계마다 심볼이 달라야 한다');
    for (final badge in badges) {
      expect(storeBadges, contains(badge), reason: '목록 밖의 배지를 쓰면 안 된다');
    }
  });

  test('pubspec이 그림이 든 칸을 담는다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('- assets/icons/'), isTrue);
  });

  test('더보기의 상품 칸 이름이 그 안의 줄 이름과 겹치지 않는다', () {
    final src = File('lib/features/settings/more/presentation/more_screen.dart')
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(src.contains("_GroupLabel('상품')"), isTrue);
    expect(src.contains("_GroupLabel('구독')"), isFalse);
  });

  testWidgets('단계마다 배지가 그 색과 심볼로 그려진다', (tester) async {
    for (final tier in SubscriptionTier.values) {
      final badge = subscriptionTierBadgeOf(tier);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LeadingIcon(icon: badge.icon, gradient: badge.colors),
        ),
      ));

      // 바탕 네모 없이 아이콘에 색을 입힌다.
      expect(find.byType(Container), findsNothing);
      expect(find.byType(ShaderMask), findsOneWidget);

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, badge.icon);
      expect(icon.color, Colors.white);
    }
  });
}
