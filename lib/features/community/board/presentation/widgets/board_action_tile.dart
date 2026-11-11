import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';

class BoardActionTile extends StatefulWidget {
  const BoardActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<BoardActionTile> createState() => _BoardActionTileState();
}

class _BoardActionTileState extends State<BoardActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor =
        widget.selected ? widget.accentColor : context.tokens.disabled;
    final borderWidth = _pressed ? 2.0 : 1.4;
    final contentColor =
        widget.selected ? widget.accentColor : colorScheme.onSurfaceVariant;
    final labelColor =
        widget.selected ? widget.accentColor : context.tokens.textSecondary;

    return AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.accentColor.withValues(alpha: 0.12)
                : context.tokens.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: contentColor),
              const SizedBox(width: AppSpacing.sm - 2),
              Text(
                widget.label,
                style: context.texts.bodyMedium.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
