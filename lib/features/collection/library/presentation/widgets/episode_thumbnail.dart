import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// [역할]
/// 에피소드 썸네일 표시 위젯.
///
/// [imageProvider]가 없으면 플레이스홀더를 표시합니다.
/// 하단에 [duration]을 표시합니다.
class EpisodeThumbnail extends StatelessWidget {
  const EpisodeThumbnail({
    super.key,
    required this.imageProvider,
    required this.duration,
    this.width = 64,
    this.height = 48,
  });

  final ImageProvider? imageProvider;
  final String? duration;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: cs.outlineVariant, width: 0.8),
      ),
      child: const Center(child: Icon(Icons.play_arrow_rounded, size: 28)),
    );

    final thumb = (imageProvider == null)
        ? placeholder
        : ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image(
              image: imageProvider!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              gaplessPlayback: true, // ✅ 깜빡임 줄이기
              filterQuality: FilterQuality.medium,
            ),
          );

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            thumb,
            if (imageProvider != null)
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  color: Colors.black26,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 20),
            ),
          ],
        ),
        if (duration != null) ...[
          const SizedBox(height: 6),
          Text(
            duration!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }
}
