// 파는 것마다의 그림. 한 곳에 모아 둔다(5차 465).
//
// 구독 단계, 광고 제거, 패롯 충전이 저마다 다른 파일에서 아이콘을 골라
// 쓰면서 꼴이 갈렸다. 어떤 줄은 회색 네모 안 단색 아이콘, 어떤 줄은
// 색이 있는 그림이었다. 여기 한 목록으로 두고 화면들이 꺼내 쓴다.
//
// 심볼은 Material Symbols 모양을 그대로 쓴다. 바탕 네모를 깔지 않고
// 색을 심볼에 입힌다(LeadingIcon이 한다).

import 'package:flutter/material.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

class StoreBadge {
  const StoreBadge({
    required this.name,
    required this.icon,
    required this.colors,
    this.asset,
  });

  /// 무엇의 그림인지. 목록을 볼 때와 테스트에서 쓴다.
  final String name;

  /// 심볼. [asset]이 있으면 그림이 대신 그려지지만, 그림을 못 읽는
  /// 자리(버튼 안 같은)에서는 이것을 쓴다.
  final IconData icon;

  /// 왼쪽 위에서 오른쪽 아래로 흐르는 두 색.
  final List<Color> colors;

  /// 직접 그린 SVG. 있으면 이것이 먼저다.
  final String? asset;
}

/// 구독 - 무료. 아직 시작 전이라 새싹, 색은 중성 회색.
const StoreBadge freeTierBadge = StoreBadge(
  name: '무료',
  icon: Icons.eco_rounded,
  colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
);

/// 구독 - 라이트.
const StoreBadge lightTierBadge = StoreBadge(
  name: '라이트',
  icon: Icons.bolt_rounded,
  colors: [Color(0xFF7DD3FC), Color(0xFF0284C7)],
);

/// 구독 - 플러스.
const StoreBadge plusTierBadge = StoreBadge(
  name: '플러스',
  icon: Icons.auto_awesome_rounded,
  colors: [Color(0xFF6EE7B7), Color(0xFF059669)],
);

/// 구독 - 프로.
const StoreBadge proTierBadge = StoreBadge(
  name: '프로',
  icon: Icons.diamond_rounded,
  colors: [Color(0xFFA78BFA), Color(0xFF6D28D9)],
);

/// 구독 - 맥스.
const StoreBadge maxTierBadge = StoreBadge(
  name: '맥스',
  icon: Icons.workspace_premium_rounded,
  colors: [Color(0xFFFCD34D), Color(0xFFD97706)],
);

/// 광고 제거. 한 번 사는 것이라 선물 상자.
const StoreBadge adsRemovalBadge = StoreBadge(
  name: '광고 제거',
  icon: Icons.card_giftcard_rounded,
  colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
  asset: 'assets/icons/store_ads_removed.svg',
);

/// 패롯 충전. 앱이 패롯을 보여 줄 때 쓰는 그림을 그대로 쓴다.
/// 색은 그 그림의 초록이다(버튼 안처럼 그림을 못 쓰는 자리에서 쓴다).
const StoreBadge parrotTopupBadge = StoreBadge(
  name: '패롯 충전',
  icon: Icons.add_circle_rounded,
  colors: [Color(0xFF6EE7B7), Color(0xFF059669)],
  asset: 'assets/currency/parrot.svg',
);

/// 화면에 쓰는 상품 그림 전부. 테스트가 이 목록을 돈다.
const List<StoreBadge> storeBadges = [
  freeTierBadge,
  lightTierBadge,
  plusTierBadge,
  proTierBadge,
  maxTierBadge,
  adsRemovalBadge,
  parrotTopupBadge,
];

StoreBadge subscriptionTierBadgeOf(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return freeTierBadge;
    case SubscriptionTier.light:
      return lightTierBadge;
    case SubscriptionTier.plus:
      return plusTierBadge;
    case SubscriptionTier.pro:
      return proTierBadge;
    case SubscriptionTier.max:
      return maxTierBadge;
  }
}

/// 상품 그림 하나를 그린다. 바탕을 깔지 않고 색을 심볼에 입힌다.
/// 더보기 줄은 LeadingIcon이 따로 그리고, 그 밖의 자리는 이것을 쓴다.
class StoreBadgeIcon extends StatelessWidget {
  const StoreBadgeIcon({super.key, required this.badge, this.size = 24});

  final StoreBadge badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: badge.colors,
      ).createShader(rect),
      child: Icon(badge.icon, size: size, color: Colors.white),
    );
  }
}
