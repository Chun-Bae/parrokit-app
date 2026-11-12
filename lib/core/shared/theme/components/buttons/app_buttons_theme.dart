// lib/theme/components/app_buttons_theme.dart
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

ButtonStyle _baseButton(ColorScheme cs, {required bool isDark}) {
  return ButtonStyle(
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    elevation: const WidgetStatePropertyAll(0),
  );
}

ElevatedButtonThemeData appElevatedButtonTheme(ColorScheme cs,
    {required bool isDark}) {
  return ElevatedButtonThemeData(
    style: _baseButton(cs, isDark: isDark).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return cs.onSurface.withValues(alpha: 0.12); // disabled container
        }
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: 0.85);
        }
        if (states.contains(WidgetState.hovered)) {
          return cs.primary.withValues(alpha: 0.92);
        }
        return cs.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return cs.onSurface.withValues(alpha: 0.38); // disabled content
        }
        return cs.onPrimary;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return cs.onPrimary.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered)) {
          return cs.onPrimary.withValues(alpha: 0.10);
        }
        return null;
      }),
    ),
  );
}

OutlinedButtonThemeData appOutlinedButtonTheme(ColorScheme cs,
    {required bool isDark}) {
  return OutlinedButtonThemeData(
    style: _baseButton(cs, isDark: isDark).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return cs.onSurface.withValues(alpha: 0.38);
        }
        return cs.primary;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3));
        }
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return BorderSide(color: cs.primary.withValues(alpha: 0.75));
        }
        return BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6));
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.hovered)) {
          return cs.primary.withValues(alpha: 0.04);
        }
        return null;
      }),
    ),
  );
}

TextButtonThemeData appTextButtonTheme(ColorScheme cs, {required bool isDark}) {
  return TextButtonThemeData(
    style: _baseButton(cs, isDark: isDark).copyWith(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return cs.surface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: 0.90);
        }
        return cs.primary;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return cs.primary.withValues(alpha: 0.05);
        }
        return null;
      }),
    ),
  );
}

ToggleButtonsThemeData appToggleButtonsTheme(ColorScheme cs,
    {required bool isDark}) {
  return ToggleButtonsThemeData(
    borderRadius: BorderRadius.circular(AppRadius.full),
    borderWidth: 1,
    borderColor: cs.outlineVariant.withValues(alpha: 0.6),
    selectedBorderColor: cs.primary,
    color: cs.onSurface.withValues(alpha: 0.74), // 기본 텍스트/아이콘
    selectedColor: cs.primary, // 선택 시 파란색 텍스트/아이콘
    fillColor: cs.primary.withValues(alpha: 0.08), // 아주 옅은 파란 배경
  );
}

FilledButtonThemeData appFilledButtonTheme(ColorScheme cs,
    {required bool isDark}) {
  return FilledButtonThemeData(
    style: _baseButton(cs, isDark: isDark).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return cs.primary.withValues(alpha: 0.06); // 약한 disabled 배경
        }
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered)) {
          return cs.primary.withValues(alpha: 0.10);
        }
        return cs.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return cs.onSurface.withValues(alpha: 0.38);
        }
        return cs.onPrimary;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return cs.primary.withValues(alpha: 0.06);
        }
        return null;
      }),
    ),
  );
}
