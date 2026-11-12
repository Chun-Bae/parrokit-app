// ============================================================================
// lib/features/recent/presentation/widgets/recent_clip_card.dart
// ============================================================================
//
// [역할]
// 최근 본 클립 카드 위젯.
// 썸네일, 제목, 작품명, 이어보기 버튼 표시.
//
// [레이어]
// Presentation Layer > Widgets
// ============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 최근 본 클립 카드.
class RecentClipCard extends StatelessWidget {
  const RecentClipCard({
    super.key,
    required this.clipId,
    required this.thumb,
    required this.clipTitle,
    required this.titleName,
    required this.onTap,
  });

  final int clipId;
  final Uint8List? thumb;
  final String clipTitle;
  final String? titleName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? .5 : .7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // 썸네일
              _Thumbnail(thumb: thumb, isDark: isDark),
              const SizedBox(width: 12),

              // 텍스트 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clipTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      titleName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 이어보기 버튼
              TextButton.icon(
                onPressed: onTap,
                icon: Icon(Icons.play_circle_fill, color: cs.primary),
                label: Text(
                  '이어보기',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  foregroundColor: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 썸네일 위젯 (16:9 비율).
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.thumb, required this.isDark});

  final Uint8List? thumb;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: 128,
        height: 72,
        child: thumb != null
            ? Image.memory(thumb!, fit: BoxFit.cover)
            : Container(
                color: isDark
                    ? context.tokens.surfaceContainerHigh
                    : cs.surfaceContainerHighest,
                child: Center(
                  child: Icon(
                    Icons.video_library_outlined,
                    size: 28,
                    color: isDark ? context.tokens.textTertiary : cs.outline,
                  ),
                ),
              ),
      ),
    );
  }
}
