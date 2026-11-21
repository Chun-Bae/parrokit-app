// lib/theme/components/app_icon_theme.dart
import 'package:flutter/material.dart';

IconThemeData appIconTheme(ColorScheme cs, {required bool isDark}) {
  return IconThemeData(
    size: 20,
    color: cs.onSurface,
  );
}
