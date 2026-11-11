// lib/core/theme/components/app_slider_theme.dart
//
// Slider 테마 - 슬라이더 스타일 통합

import 'package:flutter/material.dart';
import '../typography/app_texts_theme.dart';

/// Slider 테마
SliderThemeData appSliderTheme(ColorScheme cs, {required bool isDark}) {
  return SliderThemeData(
    activeTrackColor: cs.primary,
    inactiveTrackColor: cs.primary.withValues(alpha: 0.24),
    disabledActiveTrackColor: cs.onSurface.withValues(alpha: 0.32),
    disabledInactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
    thumbColor: cs.primary,
    disabledThumbColor: cs.onSurface.withValues(alpha: 0.38),
    overlayColor: cs.primary.withValues(alpha: 0.12),
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(
      enabledThumbRadius: 10,
      disabledThumbRadius: 8,
    ),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
    activeTickMarkColor: cs.onPrimary.withValues(alpha: 0.6),
    inactiveTickMarkColor: cs.primary.withValues(alpha: 0.6),
    valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
    valueIndicatorColor: cs.primary,
    valueIndicatorTextStyle:
        AppTextScale.bodySmall.copyWith(color: cs.onPrimary),
  );
}
