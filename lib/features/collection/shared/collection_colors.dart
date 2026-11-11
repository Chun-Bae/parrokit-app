import 'package:flutter/material.dart';

/// 보관함 화면에서 쓰는 기능 고유 색.
///
/// 앱 테마 색이 아니라 보관함 안에서만 뜻이 있는 색이라 여기에 모았다.
/// 글자색과 표면색처럼 밝기에 따라 바뀌어야 하는 값은 `AppTokens.of(context)`를 쓴다.
///
/// `AppColors`와 같은 꼴로 값만 담는다. 화면에서는 여기를 직접 쓰지 말고
/// 밝기에 맞는 쪽을 골라 주는 `context.collectionTokens`를 쓴다.
abstract final class CollectionColors {
  // ── 카드·탭 파스텔 배경 ───────────────────────────────────────
  // 같은 세 색이 보관함 탭과 문장팩 카드에서 겹쳐 쓰이고 있어 한곳에 모았다.
  // 한쪽 의미로 이름을 붙일 수 없어 색조 이름으로 둔다.

  /// 연한 민트. 문장 탭, 일상 표현 팩.
  static const Color mint = Color(0xFFDDEFEA);

  /// 다크 민트. 같은 색조를 어둡게 깐 면.
  static const Color mintDark = Color(0xFF132623);

  /// 연한 하늘. 클립 탭, 여행 표현 팩.
  static const Color sky = Color(0xFFDCE9F8);

  /// 다크 하늘.
  static const Color skyDark = Color(0xFF14212F);

  /// 연한 크림. 단어 탭, 카페 표현 팩.
  static const Color cream = Color(0xFFFFE8C7);

  /// 다크 크림.
  static const Color creamDark = Color(0xFF2B2316);

  // ── 파스텔 배경 위 글자·아이콘 ────────────────────────────────
  // 네 색이 모두 "파스텔 배경 위 아이콘·라벨"이라는 같은 역할인데 값이 다르다.
  // 지금 값을 그대로 옮겨 둔 것이고, 하나로 합치려면 화면을 보고 정해야 한다.

  /// 보관함 탭 카드의 아이콘.
  static const Color tabIcon = Color(0xFF42636A);

  /// 다크 배경 위 탭 아이콘.
  static const Color tabIconDark = Color(0xFF9CC2C7);

  /// 문장팩 카드의 아이콘.
  static const Color packIcon = Color(0xFF3D5966);

  /// 다크 배경 위 문장팩 아이콘.
  static const Color packIconDark = Color(0xFF9BBBCC);

  /// 문장팩 카드의 설명 라벨.
  static const Color packLabel = Color(0xFF526977);

  /// 다크 배경 위 설명 라벨.
  static const Color packLabelDark = Color(0xFFA3B5C0);

  /// 크림 배경 위 단어 아이콘.
  static const Color creamIcon = Color(0xFFAA6B20);

  /// 다크 크림 배경 위 단어 아이콘.
  static const Color creamIconDark = Color(0xFFE0A85C);

  // ── 동작 표시 색 ──────────────────────────────────────────────

  /// 좋아요를 누른 하트.
  static const Color liked = Color(0xFFFF768B);

  /// 다크에서 좋아요 하트. 어두운 배경에서 더 밝게 떠야 한다.
  static const Color likedDark = Color(0xFFFF8FA1);

  /// 앵무새에게 보내기가 켜진 상태의 아이콘.
  static const Color voiceActive = Color(0xFF6D9890);

  /// 다크에서 보내기 켜짐.
  static const Color voiceActiveDark = Color(0xFF8FBDB3);

  // ── 친밀도 최고 단계 카드 ─────────────────────────────────────

  /// 최고 단계 카드의 연한 황금빛 배경 그라디언트.
  static const List<Color> goldBackground = [
    Color(0xFFFFFBEA),
    Color(0xFFFFF1C9),
    Color(0xFFFFFAE6),
  ];

  /// 다크에서 최고 단계 카드의 배경 그라디언트.
  static const List<Color> goldBackgroundDark = [
    Color(0xFF2A2314),
    Color(0xFF342B16),
    Color(0xFF26200F),
  ];

  /// 최고 단계 카드의 금색 테두리 그라디언트.
  static const List<Color> goldBorder = [
    Color(0xFFF7D774),
    Color(0xFFC9972B),
    Color(0xFFFFE9A0),
  ];

  /// 다크에서 최고 단계 카드의 테두리 그라디언트.
  static const List<Color> goldBorderDark = [
    Color(0xFFC9A94E),
    Color(0xFF8F6B1E),
    Color(0xFFD9BC6E),
  ];
}
