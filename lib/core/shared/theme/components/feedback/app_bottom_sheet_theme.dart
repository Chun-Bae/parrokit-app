// lib/core/theme/components/app_bottom_sheet_theme.dart
//
// BottomSheet 테마 - Modal/Persistent BottomSheet 스타일 통합

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// BottomSheet 테마
BottomSheetThemeData appBottomSheetTheme(ColorScheme cs,
    {required bool isDark}) {
  return BottomSheetThemeData(
    backgroundColor: cs.surface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    modalBackgroundColor: cs.surface,
    modalElevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    showDragHandle: true,
    dragHandleColor: cs.outlineVariant,
    dragHandleSize: const Size(36, 4),
    constraints: const BoxConstraints(maxWidth: 600),
    clipBehavior: Clip.antiAlias,
  );
}
