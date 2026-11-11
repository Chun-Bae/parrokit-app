// lib/theme/components/app_appbar_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../typography/app_texts_theme.dart';

AppBarTheme appAppBarTheme(ColorScheme cs, {required bool isDark}) {
  // 상태바(상단 시스템 영역) 아이콘 대비 설정
  final overlay = isDark
      ? SystemUiOverlayStyle.light // 어두운 배경 → 밝은 아이콘
      : SystemUiOverlayStyle.dark; // 밝은 배경 → 어두운 아이콘

  return AppBarTheme(
    backgroundColor: cs.surface,
    foregroundColor: cs.onSurface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    toolbarHeight: 56,
    // 제목 스타일 (onSurface에 자동 맞춤)
    titleTextStyle: AppTextScale.titleLarge
        .copyWith(fontFamily: "IBMPlexSansKR", color: cs.onSurface),

    // 아이콘 색상
    iconTheme: IconThemeData(color: cs.onSurface),
    actionsIconTheme: IconThemeData(color: cs.onSurface),

    systemOverlayStyle: overlay.copyWith(
      statusBarColor: Colors.transparent,
    ),
  );
}
