import 'package:flutter/material.dart';
import 'package:parrokit/features/content-studio/shared/studio_colors.dart';

LinearGradient getGradientForMode(String mode) {
  switch (mode) {
    case 'tts':
      return const LinearGradient(
        colors: [StudioColors.purpleLight, StudioColors.ttsPink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case 'video':
      return const LinearGradient(
        colors: [StudioColors.videoBlue, StudioColors.videoCyan],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    default: // 'general'
      return const LinearGradient(
        colors: [StudioColors.generalPurple, StudioColors.videoBlue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  }
}
