// lib/theme/components/app_navigation_bar_theme.dart
import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';

BottomNavigationBarThemeData appBottomNavigationBar(ColorScheme cs,
    {required bool isDark}) {
  return BottomNavigationBarThemeData(
    type: BottomNavigationBarType.fixed,
    backgroundColor: cs.surface,
    selectedItemColor: cs.primary,
    unselectedItemColor: cs.onSurface.withValues(alpha: 0.6),
    showSelectedLabels: true,
    showUnselectedLabels: true,
    elevation: 0,
  );
}

NavigationBarThemeData appNavigationBar(ColorScheme cs,
    {required bool isDark}) {
  return NavigationBarThemeData(
    backgroundColor: cs.surface,
    elevation: 0,

    // indicator는 선택된 아이템 배경 (primary의 투명도)
    indicatorColor: cs.primary.withValues(alpha: isDark ? 0.20 : 0.12),

    // 아이콘 스타일: 선택 여부에 따라 primary vs onSurface
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 22,
        color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.74),
      );
    }),

    // 라벨 스타일: 선택 vs 미선택
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return AppTextScale.bodySmall.copyWith(
          color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.74));
    }),
  );
}
