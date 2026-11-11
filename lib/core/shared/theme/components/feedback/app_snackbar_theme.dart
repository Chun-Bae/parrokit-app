// lib/core/theme/components/app_snackbar_theme.dart
//
// SnackBar 테마 - 토스트/스낵바 메시지 스타일 통합

import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';

/// SnackBar 테마
SnackBarThemeData appSnackBarTheme(ColorScheme cs, {required bool isDark}) {
  return SnackBarThemeData(
    backgroundColor: isDark ? const Color(0xFF2C3038) : const Color(0xFF323232),
    contentTextStyle: AppTextScale.bodyMedium
        .copyWith(fontFamily: 'IBMPlexSansKR', color: Colors.white),
    actionTextColor: cs.primary,
    actionBackgroundColor: Colors.transparent,
    closeIconColor: Colors.white70,
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    showCloseIcon: false,
    dismissDirection: DismissDirection.horizontal,
  );
}
