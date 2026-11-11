import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'video_picker_sheet.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.onPick,
    required this.onPickFromPhotos,
    this.isLoading = false,
  });

  final VoidCallback onPick;
  final VoidCallback onPickFromPhotos;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: isLoading
            ? null
            : () {
                showVideoPickerSheet(
                  context: context,
                  title: '영상 추가',
                  onPickFile: onPick,
                  onPickPhotos: onPickFromPhotos,
                );
              },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: isLoading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        color: cs.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '영상을 불러오는 중...',
                        style: context.texts.bodyMedium
                            .copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 36,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '여기를 눌러 영상 선택',
                        style: context.texts.titleMedium
                            .copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '자막을 생성할 영상을 추가해주세요',
                        style: context.texts.labelMedium
                            .copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
