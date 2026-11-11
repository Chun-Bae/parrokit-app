// lib/core/theme/components/app_popup_menu_theme.dart
//
// PopupMenu 테마 - 팝업 메뉴 스타일 통합

import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// PopupMenu 테마
PopupMenuThemeData appPopupMenuTheme(ColorScheme cs, {required bool isDark}) {
  return PopupMenuThemeData(
    color: cs.surface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        width: 1,
      ),
    ),
    position: PopupMenuPosition.under,
    enableFeedback: true,
    textStyle: AppTextScale.bodyMedium.copyWith(color: cs.onSurface),
    labelTextStyle: WidgetStateProperty.all(
      AppTextScale.bodyMedium.copyWith(color: cs.onSurface),
    ),
    menuPadding: const EdgeInsets.symmetric(vertical: 8),
  );
}
