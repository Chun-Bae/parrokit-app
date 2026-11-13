import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class TogglePill extends StatelessWidget {
  const TogglePill({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.isLight = true,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color bg = active
        ? (isLight ? cs.primary.withValues(alpha: 0.14) : Colors.white24)
        : (isLight ? cs.surface.withValues(alpha: 0.9) : Colors.white12);
    final Color fg = active
        ? (isLight ? cs.primary : Colors.white)
        : (isLight ? cs.onSurface : Colors.white70);
    final Color? border = active
        ? (isLight ? cs.primary.withValues(alpha: 0.6) : Colors.white30)
        : null; // 비활성일 때는 테두리 없음

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: border != null ? Border.all(color: border, width: 0.8) : null,
        ),
        // 내용만큼만 차지한다. 줄바꿈되는 줄(Wrap)에 들어가도 가로로 늘지 않게.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
