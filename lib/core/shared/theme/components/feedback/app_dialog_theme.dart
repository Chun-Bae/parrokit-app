// lib/core/theme/components/app_dialog_theme.dart
//
// Dialog 테마 - AlertDialog, SimpleDialog 등 스타일 통합

import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';

/// Dialog 테마
DialogThemeData appDialogTheme(ColorScheme cs, {required bool isDark}) {
  return DialogThemeData(
    // 다크에서는 화면 바탕(surfaceDark)과 같은 색이라 대화상자 가장자리가 보이지
    // 않았다(5차). 한 단계 밝은 면으로 띄운다. 라이트는 그대로.
    backgroundColor: isDark ? AppColors.surfaceContainerDark : cs.surface,
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
