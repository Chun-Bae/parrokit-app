// 더보기 '구독' 줄 왼쪽 그림(5차 465).
//
// 처음에는 단계마다 SVG를 손으로 그렸는데 투박했다. 가격표 UI가 흔히
// 쓰는 꼴 - 그라데이션 배지 안에 흰 심볼 - 로 바꾸고, 심볼은 Material
// Symbols 모양을 그대로 쓴다.
//
// 단계가 올라가는 것이 색과 심볼로 함께 보이게 했다.
// 무료는 새싹(아직 시작), 라이트는 번개, 프로는 보석.

import 'package:flutter/material.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

class SubscriptionTierBadge {
  const SubscriptionTierBadge({required this.icon, required this.colors});

  final IconData icon;

  /// 왼쪽 위에서 오른쪽 아래로 흐르는 두 색.
  final List<Color> colors;
}

SubscriptionTierBadge subscriptionTierBadgeOf(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return const SubscriptionTierBadge(
        icon: Icons.eco_rounded,
        colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
      );
    case SubscriptionTier.light:
      return const SubscriptionTierBadge(
        icon: Icons.bolt_rounded,
        colors: [Color(0xFF7DD3FC), Color(0xFF0284C7)],
      );
    case SubscriptionTier.pro:
      return const SubscriptionTierBadge(
        icon: Icons.diamond_rounded,
        colors: [Color(0xFFA78BFA), Color(0xFF6D28D9)],
      );
  }
}
