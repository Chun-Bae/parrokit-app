// ============================================================================
// lib/features/dashboard/presentation/widgets/clip_thumbnail_card.dart
// ============================================================================
//
// [역할]
// 클립 썸네일 카드 위젯. 이어보기 리스트에서 각 클립을 카드로 표시.
//
// [레이어]
// Presentation Layer > Widgets
// 순수 재사용 위젯 - ContinueWatchingSection에서 사용.
// ============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 클립 썸네일 카드 위젯.
///
/// 썸네일 이미지, 작품명 라벨, 재생 버튼, 클립 제목 표시.
class ClipThumbnailCard extends StatelessWidget {
  final int clipId;
  final Uint8List? imageBytes;
  final String clipTitle;
  final String? titleName;
  final Color cardBg;
  final Color subtle;
  final VoidCallback onTap;

  const ClipThumbnailCard({
    super.key,
    required this.clipId,
    required this.imageBytes,
    required this.clipTitle,
    required this.titleName,
    required this.cardBg,
    required this.subtle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: subtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 썸네일
            Positioned.fill(
              child: imageBytes != null
                  ? Image.memory(imageBytes!, fit: BoxFit.cover)
                  : _thumbPlaceholder(),
            ),

            // 상단 라벨 (작품명)
            if (titleName != null && titleName!.isNotEmpty)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    titleName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),

            // 재생 버튼
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),

            // 하단 그라데이션 + 제목
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Text(
                  clipTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.thumbGradientStart, AppColors.thumbGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie, color: Colors.white70, size: 28),
      ),
    );
  }
}
