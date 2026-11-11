// lib/core/theme/components/app_dialog_theme.dart
//
// Dialog 테마 - AlertDialog, SimpleDialog 등 스타일 통합

import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// Dialog 테마
DialogThemeData appDialogTheme(ColorScheme cs, {required bool isDark}) {
  return DialogThemeData(
    backgroundColor: cs.surface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    titleTextStyle: AppTextScale.titleLarge.copyWith(color: cs.onSurface),
    contentTextStyle: AppTextScale.bodyMedium
        .copyWith(color: cs.onSurface.withValues(alpha: 0.8), height: 1.5),
    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  );
}
