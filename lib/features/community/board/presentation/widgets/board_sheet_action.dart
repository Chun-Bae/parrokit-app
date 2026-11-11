import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class BoardSheetAction extends StatelessWidget {
  const BoardSheetAction({
    super.key,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isDestructive ? AppColors.danger : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.texts.titleMedium.copyWith(color: textColor),
        ),
      ),
    );
  }
}
