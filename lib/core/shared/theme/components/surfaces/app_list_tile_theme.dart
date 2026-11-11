// lib/core/theme/components/app_list_tile_theme.dart
//
// ListTile 테마 - 목록 항목 스타일 통합

import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';

/// ListTile 테마
ListTileThemeData appListTileTheme(ColorScheme cs, {required bool isDark}) {
  return ListTileThemeData(
    tileColor: Colors.transparent,
    selectedTileColor: cs.primary.withValues(alpha: 0.08),
    iconColor: cs.onSurface.withValues(alpha: 0.74),
    textColor: cs.onSurface,
    selectedColor: cs.primary,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    minVerticalPadding: 8,
    horizontalTitleGap: 12,
    minLeadingWidth: 24,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    enableFeedback: true,
    dense: false,
    visualDensity: VisualDensity.compact,
    titleTextStyle: AppTextScale.titleMedium.copyWith(color: cs.onSurface),
    subtitleTextStyle: AppTextScale.labelMedium
        .copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
    leadingAndTrailingTextStyle: AppTextScale.bodyMedium
        .copyWith(color: cs.onSurface.withValues(alpha: 0.74)),
  );
}
