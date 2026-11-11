// ============================================================================
// lib/features/dashboard/presentation/widgets/more_card.dart
// ============================================================================
//
// [역할]
// "더 보러가기" 카드 위젯. 리스트 끝이나 빈 상태에서 표시.
//
// [레이어]
// Presentation Layer > Widgets
// 순수 재사용 위젯 - ContinueWatchingSection에서 사용.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// "더 보러가기" 또는 빈 상태 카드 위젯.
class MoreCard extends StatelessWidget {
  final Color subtle;
  final Color textSecondary;
  final VoidCallback onTap;
  final bool isEmpty;

  const MoreCard({
    super.key,
    required this.subtle,
    required this.textSecondary,
    required this.onTap,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        isDark ? context.tokens.surfaceContainer : context.tokens.surface;

    // 빈 상태
    if (isEmpty) {
      return Container(
        width: 220,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: subtle),
        ),
        child: Center(
          child: Text(
            '아직 등록된 클립이 없어요',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
    }

    // 더 보러가기
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: subtle),
          color: cardBg,
        ),
        child: Stack(
          children: [
            // 약한 패턴 배경
            Positioned.fill(
              child: Opacity(
                opacity: .05,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, .5, 1.0],
                      colors: [Colors.white, Colors.transparent, Colors.white],
                    ),
                  ),
                ),
              ),
            ),
            // 가운데 내용
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: subtle),
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 28,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '더 보러가기',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '라이브러리에서 전체 보기',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: textSecondary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
