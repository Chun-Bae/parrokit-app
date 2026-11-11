// ============================================================================
// lib/features/dashboard/presentation/sections/hero_section.dart
// ============================================================================
//
// [역할]
// 대시보드 히어로 카드 섹션.
// 오늘의 학습 클립을 카드 형태로 표시.
//
// [레이어]
// Presentation Layer > Sections
// DashboardScreen에서만 사용하는 화면 전용 섹션.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import '../widgets/hero_card.dart';

/// 대시보드 히어로 카드 섹션.
///
/// 오늘의 학습 클립 정보를 카드로 표시.
/// 로딩 상태와 탭 핸들러를 부모로부터 주입받음.
class HeroSection extends StatelessWidget {
  // ─────────────────────────────────────────────────────────────────
  // 파라미터
  // ─────────────────────────────────────────────────────────────────

  /// 히어로 클립 데이터 (clipId, thumbnail, clipTitle, titleName)
  final (int, dynamic, String?, String?)? heroClip;

  /// 로딩 상태
  final bool loading;

  /// 탭 콜백
  final VoidCallback onTap;

  const HeroSection({
    super.key,
    required this.heroClip,
    required this.loading,
    required this.onTap,
  });

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    final cardBg =
        isDark ? context.tokens.surfaceContainer : context.tokens.surface;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textPrimary = context.tokens.textPrimary;
    final textSecondary = context.tokens.textSecondary;

    return HeroCard(
      cardBg: cardBg,
      subtle: subtle,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: cs.primary,
      title: heroClip?.$4,
      clipTitle: heroClip?.$3,
      loading: loading,
      onTap: onTap,
    );
  }
}
