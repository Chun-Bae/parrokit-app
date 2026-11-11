// lib/core/shared/theme/components/typography/app_texts_theme.dart
import 'package:flutter/material.dart';

/// 앱 타이포 스케일.
///
/// 화면에서 `fontSize`를 직접 적는 대신 역할 이름으로 꺼내 쓴다.
/// 크기와 굵기는 여기서만 정하고, 색은 쓰는 쪽에서 `copyWith(color: …)`로 얹는다.
///
/// 정리 전에는 코드 전체에 `fontSize` 값이 23종(9 ~ 84) 흩어져 있었다.
/// 아래 표가 그 값들을 어느 역할로 모았는지다.
///
/// | 역할            | 크기 | 굵기 | 흡수한 기존 값 |
/// |-----------------|------|------|----------------|
/// | labelSmall      | 11   | w700 | 9, 10, 11      |
/// | bodySmall       | 12   | w600 | 12, 12.5       |
/// | labelMedium     | 13   | w700 | 13             |
/// | bodyMedium      | 14   | w600 | 14             |
/// | labelLarge      | 14   | w800 | (버튼 글자)    |
/// | bodyLarge       | 15   | w700 | 15             |
/// | titleMedium     | 16   | w800 | 16, 17         |
/// | titleLarge      | 18   | w800 | 18, 19         |
/// | headlineSmall   | 20   | w900 | 20, 21, 22     |
/// | headlineMedium  | 24   | w900 | 24, 25, 26     |
/// | headlineLarge   | 32   | w900 | 30, 32, 38     |
/// | displaySmall    | 52   | w900 | 52             |
///
/// 84처럼 일러스트에 쓰는 한 번뿐인 크기는 스케일에 넣지 않고 그 자리에 둔다.
abstract final class AppTextScale {
  static const labelSmall =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
  static const bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  static const labelMedium =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
  static const bodyMedium =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const labelLarge =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w800);
  static const bodyLarge = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
  static const titleMedium =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w800);
  static const titleLarge =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
  static const headlineSmall =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w900);
  static const headlineMedium =
      TextStyle(fontSize: 24, fontWeight: FontWeight.w900);
  static const headlineLarge =
      TextStyle(fontSize: 32, fontWeight: FontWeight.w900);
  static const displaySmall =
      TextStyle(fontSize: 52, fontWeight: FontWeight.w900);
}

/// 역할별 글자 스타일을 null 없이 꺼내는 창구. `context.texts.titleLarge` 처럼 쓴다.
///
/// 테마에 슬롯이 비어 있으면 [AppTextScale]의 값으로 떨어지므로,
/// 화면이 테마를 통째로 바꿔도 글자가 기본 크기로 깨지지 않는다.
@immutable
class AppTexts {
  const AppTexts(this._theme);

  final TextTheme _theme;

  TextStyle get labelSmall => _theme.labelSmall ?? AppTextScale.labelSmall;
  TextStyle get bodySmall => _theme.bodySmall ?? AppTextScale.bodySmall;
  TextStyle get labelMedium => _theme.labelMedium ?? AppTextScale.labelMedium;
  TextStyle get bodyMedium => _theme.bodyMedium ?? AppTextScale.bodyMedium;
  TextStyle get labelLarge => _theme.labelLarge ?? AppTextScale.labelLarge;
  TextStyle get bodyLarge => _theme.bodyLarge ?? AppTextScale.bodyLarge;
  TextStyle get titleMedium => _theme.titleMedium ?? AppTextScale.titleMedium;
  TextStyle get titleLarge => _theme.titleLarge ?? AppTextScale.titleLarge;
  TextStyle get headlineSmall =>
      _theme.headlineSmall ?? AppTextScale.headlineSmall;
  TextStyle get headlineMedium =>
      _theme.headlineMedium ?? AppTextScale.headlineMedium;
  TextStyle get headlineLarge =>
      _theme.headlineLarge ?? AppTextScale.headlineLarge;
  TextStyle get displaySmall =>
      _theme.displaySmall ?? AppTextScale.displaySmall;
}

extension AppTextsContext on BuildContext {
  /// 역할별 글자 스타일. `context.texts.bodySmall.copyWith(color: …)`
  AppTexts get texts => AppTexts(Theme.of(this).textTheme);
}

TextTheme appTextTheme(ColorScheme cs, {required bool isDark}) {
  final cPrimary = cs.onSurface;
  final cSecondary = cs.onSurface.withValues(alpha: 0.74);
  final cTertiary = cs.onSurface.withValues(alpha: 0.56);

  return TextTheme(
    displaySmall: AppTextScale.displaySmall.copyWith(color: cPrimary),
    headlineLarge: AppTextScale.headlineLarge.copyWith(color: cPrimary),
    headlineMedium: AppTextScale.headlineMedium.copyWith(color: cPrimary),
    headlineSmall: AppTextScale.headlineSmall.copyWith(color: cPrimary),
    titleLarge: AppTextScale.titleLarge.copyWith(color: cPrimary),
    titleMedium: AppTextScale.titleMedium.copyWith(color: cPrimary),
    bodyLarge: AppTextScale.bodyLarge.copyWith(color: cPrimary),
    bodyMedium: AppTextScale.bodyMedium.copyWith(color: cSecondary),
    bodySmall: AppTextScale.bodySmall.copyWith(color: cTertiary),
    labelLarge: AppTextScale.labelLarge.copyWith(color: cs.onPrimary),
    labelMedium: AppTextScale.labelMedium.copyWith(color: cSecondary),
    labelSmall: AppTextScale.labelSmall.copyWith(color: cTertiary),
  );
}

TextSelectionThemeData appTextSelectionTheme(ColorScheme cs,
    {required bool isDark}) {
  return TextSelectionThemeData(
    cursorColor: cs.primary,
    selectionColor: cs.primary.withValues(alpha: 0.16),
    selectionHandleColor: cs.primary,
  );
}
