// lib/theme/components/app_input_theme.dart
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

InputDecorationTheme appInputDecorationTheme(ColorScheme cs,
    {required bool isDark}) {
  OutlineInputBorder baseBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color, width: width),
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
    );
  }

  return InputDecorationTheme(
    filled: true,
    fillColor: cs.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

    // 힌트 텍스트 색상 → onSurface의 투명도 조절
    hintStyle: TextStyle(
      color: cs.onSurface.withValues(alpha: isDark ? 0.56 : 0.45),
      fontWeight: FontWeight.w600,
    ),

    // 기본 테두리
    border: baseBorder(cs.outlineVariant),
    enabledBorder: baseBorder(cs.outlineVariant),

    // 포커스 시 → primary 컬러 강조
    focusedBorder: baseBorder(cs.primary, width: 1.2),

    // 에러 시 → error 컬러
    errorBorder: baseBorder(cs.error),
    focusedErrorBorder: baseBorder(cs.error, width: 1.2),

    // 라벨 스타일 (선택사항)
    labelStyle: TextStyle(
      color: cs.onSurface.withValues(alpha: 0.74),
      fontWeight: FontWeight.w600,
    ),
  );
}
