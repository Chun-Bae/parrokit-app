// lib/theme/components/app_dropdown_theme.dart
import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';

DropdownMenuThemeData appDropdownMenuTheme(ColorScheme cs,
    {required bool isDark}) {
  return DropdownMenuThemeData(
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(cs.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          side: BorderSide(color: cs.outlineVariant, width: 1),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),

    // 여기서는 그냥 TextStyle만 넘겨야 함
    textStyle: AppTextScale.bodyMedium.copyWith(color: cs.onSurface),

    // 입력 필드(트리거) 스타일
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: cs.outlineVariant, width: 1),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.outlineVariant, width: 1),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.primary, width: 1.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      hintStyle: TextStyle(
        color: cs.onSurface.withValues(alpha: isDark ? 0.56 : 0.45),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
