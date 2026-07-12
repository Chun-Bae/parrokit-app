// ============================================================================
// lib/features/dashboard/presentation/widgets/collection_card.dart
// ============================================================================
//
// [역할]
// 모음집(작품) 카드 위젯. 작품명, 클립 수를 카드로 표시.
//
// [레이어]
// Presentation Layer > Widgets
// 순수 재사용 위젯 - CollectionsSection에서 사용.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 모음집 카드 위젯.
///
/// 작품명(한국어/일본어)과 클립 수를 표시.
class CollectionCard extends StatelessWidget {
  final int titleId;
  final String nameKo;
  final int clipCount;
  final String? storageMode;
  final Color cardBg;
  final Color subtle;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const CollectionCard({
    super.key,
    required this.titleId,
    required this.nameKo,
    required this.clipCount,
    this.storageMode,
    required this.cardBg,
    required this.subtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  String? get _storageLabel => switch (storageMode) {
        ClipStorageConstants.storageModeLocal => '로컬',
        ClipStorageConstants.storageModeServer => '서버',
        ClipStorageConstants.storageModeGoogleDrive => '클라우드',
        _ => null,
      };

  // 대시보드 테마의 ColorScheme.secondary/tertiary는 은은한 톤으로 맞춰져
  // 있어(예: secondary = primarySoft) 배지 색으로 쓰면 거의 안 보인다.
  // 3개 저장위치가 뚜렷이 구분되도록 AppColors의 선명한 색을 직접 쓴다.
  Color _storageColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (storageMode) {
      ClipStorageConstants.storageModeServer =>
        isDark ? AppColors.secondaryDark : AppColors.secondary,
      ClipStorageConstants.storageModeGoogleDrive =>
        isDark ? AppColors.successDark : AppColors.success,
      _ => isDark ? AppColors.primaryDark : AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final storageLabel = _storageLabel;
    final storageColor = _storageColor(context);

    return SizedBox(
      width: 180,
      height: 130,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: subtle),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 한국어 이름 + 저장위치 배지
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        nameKo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                      ),
                    ),
                    if (storageLabel != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: storageColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: storageColor.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          storageLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: storageColor,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),

                // 클립 수
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '클립 $clipCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
