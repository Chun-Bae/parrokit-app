// lib/core/theme/components/app_fab_theme.dart
//
// FloatingActionButton 테마 - FAB 스타일 통합

import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';

/// FloatingActionButton 테마
FloatingActionButtonThemeData appFabTheme(ColorScheme cs,
    {required bool isDark}) {
  return FloatingActionButtonThemeData(
    backgroundColor: cs.primary,
    foregroundColor: cs.onPrimary,
    splashColor: cs.onPrimary.withValues(alpha: 0.12),
    focusColor: cs.onPrimary.withValues(alpha: 0.12),
    hoverColor: cs.onPrimary.withValues(alpha: 0.08),
    elevation: 0,
    focusElevation: 0,
    hoverElevation: 0,
    highlightElevation: 0,
    disabledElevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    enableFeedback: true,
    sizeConstraints: const BoxConstraints.tightFor(width: 56, height: 56),
    smallSizeConstraints: const BoxConstraints.tightFor(width: 40, height: 40),
    largeSizeConstraints: const BoxConstraints.tightFor(width: 96, height: 96),
    extendedSizeConstraints: const BoxConstraints.tightFor(height: 48),
    extendedTextStyle: AppTextScale.bodyMedium
        .copyWith(color: cs.onPrimary, letterSpacing: 0.1),
    extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
    extendedIconLabelSpacing: 8,
  );
}
