import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/speed_label.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class SpeedMenu extends StatelessWidget {
  const SpeedMenu(
      {super.key,
      required this.value,
      required this.onSelected,
      this.isLight = true});

  final double value;
  final ValueChanged<double> onSelected;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

    return PopupMenuButton<double>(
      tooltip: '재생 속도',
      onSelected: onSelected,
      itemBuilder: (ctx) => [
        for (final s in speeds)
          PopupMenuItem<double>(
            value: s,
            child: Text(speedLabel(s)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isLight ? cs.surface.withValues(alpha: 0.9) : Colors.white12,
          borderRadius: BorderRadius.circular(AppRadius.full),
          // 옆 알약(TogglePill)의 꺼진 모습과 같은 테두리. 없으면 흰 화면에서
          // 버튼으로 보이지 않았다(5차).
          border: Border.all(
            color: isLight ? cs.outlineVariant : Colors.white24,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, size: 18),
            const SizedBox(width: 6),
            Text(speedLabel(value),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isLight ? cs.onSurface : Colors.white)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}
