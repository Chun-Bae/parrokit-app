import 'package:flutter/material.dart';

/// 보관함 화면에서 쓰는 기능 고유 색.
///
/// 앱 테마 색이 아니라 보관함 안에서만 뜻이 있는 색이라 여기에 모았다.
/// 글자색과 표면색처럼 밝기에 따라 바뀌어야 하는 값은 `AppTokens.of(context)`를 쓴다.
///
/// 다크 모드 대응은 아직 없다. 모두 밝은 배경 전용이다.
abstract final class CollectionColors {
  // ── 카드·탭 파스텔 배경 ───────────────────────────────────────
  // 같은 세 색이 보관함 탭과 문장팩 카드에서 겹쳐 쓰이고 있어 한곳에 모았다.
  // 한쪽 의미로 이름을 붙일 수 없어 색조 이름으로 둔다.

  /// 연한 민트. 문장 탭, 일상 표현 팩.
  static const Color mint = Color(0xFFDDEFEA);

  /// 연한 하늘. 클립 탭, 여행 표현 팩.
  static const Color sky = Color(0xFFDCE9F8);

  /// 연한 크림. 단어 탭, 카페 표현 팩.
  static const Color cream = Color(0xFFFFE8C7);

  // ── 파스텔 배경 위 글자·아이콘 ────────────────────────────────
  // 네 색이 모두 "파스텔 배경 위 아이콘·라벨"이라는 같은 역할인데 값이 다르다.
  // 지금 값을 그대로 옮겨 둔 것이고, 하나로 합치려면 화면을 보고 정해야 한다.

  /// 보관함 탭 카드의 아이콘.
  static const Color tabIcon = Color(0xFF42636A);

  /// 문장팩 카드의 아이콘.
  static const Color packIcon = Color(0xFF3D5966);

  /// 문장팩 카드의 설명 라벨.
  static const Color packLabel = Color(0xFF526977);

  /// 크림 배경 위 단어 아이콘.
  static const Color creamIcon = Color(0xFFAA6B20);

  // ── 동작 표시 색 ──────────────────────────────────────────────

  /// 좋아요를 누른 하트.
  static const Color liked = Color(0xFFFF768B);

  /// 앵무새에게 보내기가 켜진 상태의 아이콘.
  static const Color voiceActive = Color(0xFF6D9890);

  // ── 친밀도 최고 단계 카드 ─────────────────────────────────────

  /// 최고 단계 카드의 연한 황금빛 배경 그라디언트.
  static const List<Color> goldBackground = [
    Color(0xFFFFFBEA),
    Color(0xFFFFF1C9),
    Color(0xFFFFFAE6),
  ];

  /// 최고 단계 카드의 금색 테두리 그라디언트.
  static const List<Color> goldBorder = [
    Color(0xFFF7D774),
    Color(0xFFC9972B),
    Color(0xFFFFE9A0),
  ];
}
