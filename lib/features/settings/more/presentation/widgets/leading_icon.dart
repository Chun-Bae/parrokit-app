import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';

class LeadingIcon extends StatelessWidget {
  const LeadingIcon({super.key, required this.icon, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = danger
        ? context.tokens.danger.withValues(alpha: 0.08)
        : cs.onSurface.withValues(alpha: 0.06);
    final fg =
        danger ? context.tokens.danger : cs.onSurface.withValues(alpha: 0.75);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant, width: 0.8),
      ),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}
