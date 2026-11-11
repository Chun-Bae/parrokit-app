import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'leading_icon.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';

// lib/widgets/nav_tile.dart
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.showArrow = true,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool showArrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final textColor = danger ? context.tokens.danger : cs.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            LeadingIcon(icon: icon, danger: danger),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      )),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        subtitle!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 👉 우측 구성: trailing 우선, 없으면 화살표
            if (trailing != null)
              trailing!
            else if (showArrow)
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}
