// lib/theme/components/app_card_theme.dart
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

CardThemeData appCardTheme(ColorScheme cs, {required bool isDark}) {
  return CardThemeData(
    color: cs.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(
        color: cs.outlineVariant, // 라이트/다크 자동 대응
        width: 1,
      ),
    ),
    margin: EdgeInsets.zero,
  );
}
