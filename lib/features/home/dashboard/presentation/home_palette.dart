import 'package:flutter/material.dart';

/// 홈(앵무새 무대, 연습 기록, 학습 허브)이 함께 쓰는 색 묶음.
///
/// 이 화면들은 앱 공통 [ColorScheme]과 다른 부드러운 하늘색 계열을 쓰기 때문에
/// 색을 화면마다 직접 적어왔다. 라이트 값은 그때 쓰던 값을 그대로 옮긴 것이라
/// 라이트 모드 화면은 이전과 같고, 다크 모드에서만 어두운 값으로 바뀐다.
class HomePalette {
  const HomePalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSoft,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.primary,
    required this.border,
    required this.good,
    required this.goodSoft,
    required this.shadow,
    required this.garden,
    required this.like,
    required this.likeSoft,
    required this.likeInk,
    required this.mastery,
  });

  /// 화면 배경.
  final Color background;

  /// 카드 배경.
  final Color surface;

  /// 옅게 채운 카드나 칩 배경.
  final Color surfaceAlt;

  /// surfaceAlt보다 더 옅은 영역 배경.
  final Color surfaceSoft;

  /// 본문 글자.
  final Color ink;

  /// 본문보다 조금 연한 글자.
  final Color inkSoft;

  /// 설명과 보조 글자.
  final Color muted;

  /// 주요 버튼 배경.
  final Color accent;

  /// 주요 버튼 글자.
  final Color onAccent;

  /// 강조 아이콘과 링크.
  final Color primary;

  /// 테두리와 구분선.
  final Color border;

  /// 목표 달성처럼 좋은 상태를 가리키는 색.
  final Color good;

  /// [good]을 옅게 채운 배경.
  final Color goodSoft;

  /// 카드 그림자 색(투명도는 쓰는 쪽에서 정한다).
  final Color shadow;

  /// 학습 잔디 단계 색. 0단계(안 함)부터 4단계(목표 초과)까지.
  final List<Color> garden;

  /// 좋아요와 인기 표시 색.
  final Color like;

  /// [like]를 옅게 채운 배경.
  final Color likeSoft;

  /// [likeSoft] 배경 위에 쓰는 글자 색.
  final Color likeInk;

  /// 문장 친밀도 단계 색. 처음, 익히는 중, 익숙함 순서.
  final List<Color> mastery;

  static const light = HomePalette(
    background: Color(0xFFF3F8FD),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8EFF7),
    surfaceSoft: Color(0xFFF0F5FA),
    ink: Color(0xFF24364F),
    inkSoft: Color(0xFF415C7A),
    muted: Color(0xFF61758D),
    accent: Color(0xFFA8CBE8),
    onAccent: Color(0xFF24364F),
    primary: Color(0xFF4F6EAF),
    border: Color(0xFFD9E3EA),
    good: Color(0xFF477B70),
    goodSoft: Color(0xFFDDEFEA),
    shadow: Color(0xFF46637A),
    garden: [
      Color(0xFFF0F5FA),
      Color(0xFFDDEAF8),
      Color(0xFFB9D2EF),
      Color(0xFF82A8D8),
      Color(0xFF4F6EAF),
    ],
    like: Color(0xFFFF657E),
    likeSoft: Color(0xFFFFE5E9),
    likeInk: Color(0xFFBC4055),
    mastery: [
      Color(0xFFD9E3EA),
      Color(0xFFA8CBE8),
      Color(0xFF6D9890),
    ],
  );

  static const dark = HomePalette(
    background: Color(0xFF101722),
    surface: Color(0xFF18212E),
    surfaceAlt: Color(0xFF1F2B3A),
    surfaceSoft: Color(0xFF1A2432),
    ink: Color(0xFFE6EDF6),
    inkSoft: Color(0xFFBBCBDD),
    muted: Color(0xFF93A4B8),
    accent: Color(0xFF3E5C7D),
    onAccent: Color(0xFFE6EDF6),
    primary: Color(0xFF7FA6E8),
    border: Color(0xFF2A3747),
    good: Color(0xFF7FC2AE),
    goodSoft: Color(0xFF1C3A33),
    shadow: Color(0xFF000000),
    garden: [
      Color(0xFF1C2735),
      Color(0xFF26384D),
      Color(0xFF32516E),
      Color(0xFF466F97),
      Color(0xFF7FA6E8),
    ],
    like: Color(0xFFFF8097),
    likeSoft: Color(0xFF3A1F26),
    likeInk: Color(0xFFFFADBB),
    mastery: [
      Color(0xFF2A3747),
      Color(0xFF3E5C7D),
      Color(0xFF4E7D73),
    ],
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static HomePalette of(BuildContext context) => isDark(context) ? dark : light;
}
