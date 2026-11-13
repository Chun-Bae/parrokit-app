// ============================================================================
// lib/features/dashboard/presentation/widgets/hero_card.dart
// ============================================================================
//
// [역할]
// 히어로 카드 위젯. 오늘의 학습 클립 정보를 카드로 표시.
//
// [레이어]
// Presentation Layer > Widgets
// 순수 재사용 위젯.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 히어로 카드 위젯.
///
/// 작품명과 클립 제목을 표시하고, 탭 시 재생 화면으로 이동.
class HeroCard extends StatelessWidget {
  final Color cardBg;
  final Color subtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final String? title;
  final String? clipTitle;
  final bool loading;
  final VoidCallback? onTap;

  const HeroCard({
    super.key,
    required this.cardBg,
    required this.subtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    this.title,
    this.clipTitle,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: subtle),
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child:
                Icon(Icons.play_circle_fill_rounded, color: accent, size: 28),
          ),
          const SizedBox(width: 14),

          // 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title ?? '오늘의 학습',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (loading)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  clipTitle ?? '영상을 시청해보세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 화살표 버튼
          IconButton(
            tooltip: '열기',
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}
