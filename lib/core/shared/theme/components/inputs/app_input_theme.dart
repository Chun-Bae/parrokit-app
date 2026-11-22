// lib/theme/components/app_input_theme.dart
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

InputDecorationTheme appInputDecorationTheme(ColorScheme cs,
    {required bool isDark}) {
  OutlineInputBorder baseBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color, width: width),
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
    );
  }

  return InputDecorationTheme(
    filled: true,
    fillColor: cs.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

    // 힌트 텍스트 색상 → onSurface의 투명도 조절
    hintStyle: TextStyle(
      color: cs.onSurface.withValues(alpha: isDark ? 0.56 : 0.45),
      fontWeight: FontWeight.w600,
    ),

    // 기본 테두리
    border: baseBorder(cs.outlineVariant),
    enabledBorder: baseBorder(cs.outlineVariant),

    // 포커스 시 → primary 컬러 강조
    focusedBorder: baseBorder(cs.primary, width: 1.2),

    // 에러 시 → error 컬러
    errorBorder: baseBorder(cs.error),
    focusedErrorBorder: baseBorder(cs.error, width: 1.2),

    // 라벨 스타일 (선택사항)
    labelStyle: TextStyle(
      color: cs.onSurface.withValues(alpha: 0.74),
      fontWeight: FontWeight.w600,
    ),
  );
}

/// 테두리 없이 면으로만 그리는 입력칸(5차 565, 사용자 요청: "저 테두리가 너무
/// 싫어").
///
/// 전역 [appInputDecorationTheme]은 `filled + OutlineInputBorder(outlineVariant)`
/// 다. 칸 색이 시트 배경(cs.surface)과 같아서 얇은 선만 남고, 그런 칸이 일고여덟
/// 개 쌓이면 폼이 철망처럼 보인다. 여기서는 면으로 칸을 보이고 선은 **초점이
/// 있을 때만** 그린다. 전역 테마를 바꾸면 앱 전체가 함께 바뀌므로 두지 않고,
/// 쓰는 화면이 골라 쓴다.
///
/// [showCounter]가 거짓이면 글자 수를 감춘다. 참이면 `counterText`를 비워 두어
/// [nearLimitCounter] 같은 `buildCounter`가 돌 수 있게 비켜 준다.
InputDecoration filledInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? helper,
  Widget? suffixIcon,
  bool showCounter = false,
  Color? fillColor,
}) {
  final cs = Theme.of(context).colorScheme;
  OutlineInputBorder shape([BorderSide? side]) => OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.input)),
        borderSide: side ?? BorderSide.none,
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor ?? context.tokens.surfaceContainerHigh,
    counterText: showCounter ? null : '',
    contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    border: shape(),
    enabledBorder: shape(),
    disabledBorder: shape(),
    focusedBorder: shape(BorderSide(color: cs.primary, width: 1.6)),
    errorBorder: shape(BorderSide(color: cs.error, width: 1.2)),
    focusedErrorBorder: shape(BorderSide(color: cs.error, width: 1.6)),
    labelStyle:
        TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
    floatingLabelStyle:
        TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
    helperStyle: TextStyle(color: cs.onSurfaceVariant),
    suffixIconColor: cs.onSurfaceVariant,
  );
}

/// 한도에 가까워졌을 때만 '280/300'을 적는다(5차 565).
///
/// 칸마다 카운터를 그리면 칸 하나에 20px씩 먹는데, 200자 한도에 '3/200'은
/// 아무도 읽지 않는다. null을 돌려주면 카운터 위젯이 아예 붙지 않는다.
Widget? nearLimitCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) {
  if (maxLength == null || currentLength < maxLength * 0.9) return null;
  final cs = Theme.of(context).colorScheme;
  return Text(
    '$currentLength/$maxLength',
    style: context.texts.labelSmall.copyWith(
      color: currentLength >= maxLength ? cs.error : cs.onSurfaceVariant,
    ),
  );
}
