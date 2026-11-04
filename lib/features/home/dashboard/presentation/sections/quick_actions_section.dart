// ============================================================================
// lib/features/dashboard/presentation/sections/quick_actions_section.dart
// ============================================================================
//
// [역할]
// 대시보드 퀵 액션 버튼 섹션.
// 추가, 라이브러리, 검색, 설정 버튼을 가로 스크롤로 표시.
//
// [레이어]
// Presentation Layer > Sections
// DashboardScreen에서만 사용하는 화면 전용 섹션.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import '../widgets/quick_action_button.dart';

/// 대시보드 퀵 액션 버튼 섹션.
///
/// 가로 스크롤 가능한 버튼 리스트.
/// 각 버튼 탭 콜백을 부모로부터 주입받음.
class QuickActionsSection extends StatelessWidget {
  // ─────────────────────────────────────────────────────────────────
  // 콜백 파라미터
  // ─────────────────────────────────────────────────────────────────

  final VoidCallback onTapAdd;
  final VoidCallback onTapLibrary;
  final VoidCallback onTapSearch;
  final VoidCallback onTapSettings;

  const QuickActionsSection({
    super.key,
    required this.onTapAdd,
    required this.onTapLibrary,
    required this.onTapSearch,
    required this.onTapSettings,
  });

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.surfaceContainerDark : AppColors.surface;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return SizedBox(
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            const SizedBox(width: 4),
            QuickActionButton(
              label: '추가',
              icon: Icons.file_download_rounded,
              cardBg: cardBg,
              subtle: subtle,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: onTapAdd,
            ),
            const SizedBox(width: 12),
            QuickActionButton(
              label: '보관함',
              icon: Icons.inventory_2_rounded,
              cardBg: cardBg,
              subtle: subtle,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: onTapLibrary,
            ),
            const SizedBox(width: 4),
            QuickActionButton(
              label: '검색',
              icon: Icons.search_rounded,
              cardBg: cardBg,
              subtle: subtle,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: onTapSearch,
            ),
            const SizedBox(width: 12),
            QuickActionButton(
              label: '설정',
              icon: Icons.settings_rounded,
              cardBg: cardBg,
              subtle: subtle,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: onTapSettings,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
