import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class TtsSliderPreview extends StatelessWidget {
  const TtsSliderPreview({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.activeColor,
    this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final Color? activeColor;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              valueText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final percent =
                max > min ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final newPercent =
                    (details.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                onChanged?.call(min + (max - min) * newPercent);
              },
              onHorizontalDragUpdate: (details) {
                final newPercent =
                    (details.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                onChanged?.call(min + (max - min) * newPercent);
              },
              child: Container(
                height: 24, // 터치 영역
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.tokens.dividerSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.track),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: activeColor ?? theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppRadius.track),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth * percent) - 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
