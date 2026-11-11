import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';

class TtsOptionRow extends StatelessWidget {
  const TtsOptionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.accentColor,
    this.isGemini = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? accentColor;
  final bool isGemini;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = accentColor ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? context.tokens.surfaceContainerHigh
              : context.tokens.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            if (isGemini)
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.geminiGradient.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Icon(icon, size: 20, color: Colors.white),
              )
            else
              Icon(icon, size: 20, color: primaryColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ] else if (title == '보이스') ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
