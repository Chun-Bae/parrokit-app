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
    // 바텀시트 뒤에 깔리던 어두운 막을 없앤다(5차, 사용자 의견). 막이 있으면
    // 뒤 화면이 칙칙하게 비쳐서 가려진 건지 흐려진 건지 헷갈렸다. 투명해도
    // 바깥을 누르면 그대로 닫힌다.
    modalBarrierColor: Colors.transparent,
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
