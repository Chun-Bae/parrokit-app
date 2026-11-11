// lib/core/theme/components/app_checkbox_theme.dart
//
// Checkbox 테마 - 체크박스 스타일 통합

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// Checkbox 테마
CheckboxThemeData appCheckboxTheme(ColorScheme cs, {required bool isDark}) {
  return CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return cs.onSurface.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.selected)) {
        return cs.primary;
      }
      return Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(cs.onPrimary),
    side: WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(
            color: cs.onSurface.withValues(alpha: 0.38), width: 1.5);
      }
      if (states.contains(WidgetState.selected)) {
        return BorderSide.none;
      }
      return BorderSide(color: cs.outline, width: 1.5);
    }),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    splashRadius: 20,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );
}
