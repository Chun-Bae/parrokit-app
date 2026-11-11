// lib/core/theme/app_colors.dart
//
// 앱 전역 색상 시스템 - Toss-like Blue 베이스

import 'package:flutter/material.dart';

/// 앱 전역 색상 상수
///
/// Toss 스타일 블루 기반의 일관된 색상 팔레트
abstract final class AppColors {
  // ═══════════════════════════════════════════════════════════════════
  // Light Mode
  // ═══════════════════════════════════════════════════════════════════

  // ─────────────────────────────────────────────────────────────────
  // Surface (배경)
  // ─────────────────────────────────────────────────────────────────

  /// 기본 배경 (흰색)
  static const Color surface = Color(0xFFFFFFFF);

  /// 카드/컨테이너 배경
  static const Color surfaceContainer = Color(0xFFF7F8FA);

  /// 강조 컨테이너 배경
  static const Color surfaceContainerHigh = Color(0xFFF0F2F5);

  /// 구분선 (10% 검정)
  static const Color divider = Color(0x1A000000);

  /// 얇은 구분선 (6% 검정)
  static const Color dividerSubtle = Color(0x0F000000);

  /// 입력창과 외곽선 버튼의 또렷한 테두리. 구분선보다 진하고 글자색보다 연하다.
  static const Color borderStrong = Color(0xFFBDC4CC);

  // ─────────────────────────────────────────────────────────────────
  // Text (텍스트)
  // ─────────────────────────────────────────────────────────────────

  /// 주요 텍스트 (거의 검정)
  static const Color textPrimary = Color(0xFF111418);

  /// 보조 텍스트 (회색)
  static const Color textSecondary = Color(0xFF5B636E);

  /// 힌트/비활성 텍스트
  static const Color textTertiary = Color(0xFF8C95A1);

  /// 비활성 텍스트 (더 연함)
  static const Color textDisabled = Color(0xFFADB5BD);

  // ─────────────────────────────────────────────────────────────────
  // Accent (강조 - Toss Blue)
  // ─────────────────────────────────────────────────────────────────

  /// 프라이머리 블루 (토스 블루)
  static const Color primary = Color(0xFF0064FF);

  /// 프라이머리 호버/눌림
  static const Color primaryPressed = Color(0xFF0052D4);

  /// 프라이머리 소프트 배경 (버튼/칩 배경용)
  static const Color primarySoft = Color(0xFFE8F1FF);

  /// 프라이머리 아주 연한 배경 (선택 하이라이트)
  static const Color primarySubtle = Color(0xFFF5F9FF);

  // ─────────────────────────────────────────────────────────────────
  // Secondary (보조 컬러)
  // ─────────────────────────────────────────────────────────────────

  /// 보조 퍼플 (프리미엄/특별 기능)
  static const Color secondary = Color(0xFF7C3AED);

  /// 보조 퍼플 소프트
  static const Color secondarySoft = Color(0xFFF3EEFF);

  // ─────────────────────────────────────────────────────────────────
  // Feedback (피드백)
  // ─────────────────────────────────────────────────────────────────

  /// 성공 (그린)
  static const Color success = Color(0xFF16A34A);

  /// 성공 소프트 배경
  static const Color successSoft = Color(0xFFECFDF5);

  /// 경고 (옐로우/앰버)
  static const Color warning = Color(0xFFF59E0B);

  /// 경고 소프트 배경
  static const Color warningSoft = Color(0xFFFFFBEB);

  /// 위험/에러 (레드)
  static const Color danger = Color(0xFFDC2626);

  /// 위험 소프트 배경
  static const Color dangerSoft = Color(0xFFFEF2F2);

  /// 정보 (블루 - 프라이머리와 동일)
  static const Color info = Color(0xFF0064FF);

  /// 정보 소프트 배경
  static const Color infoSoft = Color(0xFFE8F1FF);

  // ─────────────────────────────────────────────────────────────────
  // Interactive (상호작용)
  // ─────────────────────────────────────────────────────────────────

  /// 링크 텍스트
  static const Color link = Color(0xFF0064FF);

  /// 비활성 요소 배경
  static const Color disabled = Color(0xFFE9ECEF);

  /// 비활성 요소 전경
  static const Color disabledForeground = Color(0xFF868E96);

  // ─────────────────────────────────────────────────────────────────
  // Skeleton & Overlay
  // ─────────────────────────────────────────────────────────────────

  /// 스켈레톤 로딩 배경
  static const Color skeleton = Color(0xFFE9ECEF);

  /// 스켈레톤 하이라이트 (shimmer)
  static const Color skeletonHighlight = Color(0xFFF8F9FA);

  /// 오버레이 (모달 뒤 배경)
  static const Color overlay = Color(0x80000000);

  /// 라이트 오버레이 (드롭다운 등)
  static const Color overlayLight = Color(0x1A000000);

  /// 스낵바 배경. Material 관례에 따라 라이트 모드에서도 어두운 색을 쓴다.
  static const Color snackbarSurface = Color(0xFF323232);

  // ─────────────────────────────────────────────────────────────────
  // Gradient (그라디언트)
  // ─────────────────────────────────────────────────────────────────

  /// 그라디언트 시작색 (블루)
  static const Color gradientStart = Color(0xFF3B82F6);

  /// 그라디언트 끝색 (민트)
  static const Color gradientEnd = Color(0xFF06B6D4);

  /// 썸네일 다크 그라디언트 시작
  static const Color thumbGradientStart = Color(0xFF0f172a);

  /// 썸네일 다크 그라디언트 끝
  static const Color thumbGradientEnd = Color(0xFF1f2937);

  /// 계정 카드 그라데이션 (라이트)
  static const LinearGradient accountCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8FAFF), // 아주 연한 블루
      Color(0xFFF0F4FF), // 살짝 더 진한 블루
    ],
  );

  /// 계정 카드 그라데이션 (다크)
  static const LinearGradient accountCardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1F2E), // 어두운 네이비
      Color(0xFF1F2438), // 살짝 퍼플틱한 네이비
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // Dark Mode
  // ═══════════════════════════════════════════════════════════════════

  // ─────────────────────────────────────────────────────────────────
  // Surface (배경)
  // ─────────────────────────────────────────────────────────────────

  /// 다크 기본 배경
  static const Color surfaceDark = Color(0xFF0D0F12);

  /// 다크 카드/컨테이너 배경
  static const Color surfaceContainerDark = Color(0xFF1A1D21);

  /// 다크 강조 컨테이너
  static const Color surfaceContainerHighDark = Color(0xFF24272C);

  /// 다크 구분선 (20% 흰색)
  static const Color dividerDark = Color(0x33FFFFFF);

  /// 다크 얇은 구분선
  static const Color dividerSubtleDark = Color(0x1AFFFFFF);

  /// 다크 또렷한 테두리
  static const Color borderStrongDark = Color(0xFF3F454E);

  // ─────────────────────────────────────────────────────────────────
  // Text (텍스트)
  // ─────────────────────────────────────────────────────────────────

  /// 다크 주요 텍스트
  static const Color textPrimaryDark = Color(0xFFECEFF3);

  /// 다크 보조 텍스트
  static const Color textSecondaryDark = Color(0xFFB0B8C1);

  /// 다크 힌트 텍스트
  static const Color textTertiaryDark = Color(0xFF7A828C);

  /// 다크 비활성 텍스트
  static const Color textDisabledDark = Color(0xFF5A6270);

  // ─────────────────────────────────────────────────────────────────
  // Accent (강조 - Toss Blue, 다크 조정)
  // ─────────────────────────────────────────────────────────────────

  /// 다크 프라이머리 (약간 밝게)
  static const Color primaryDark = Color(0xFF3C8DFF);

  /// 다크 프라이머리 눌림
  static const Color primaryPressedDark = Color(0xFF5A9FFF);

  /// 다크 프라이머리 소프트 (어두운 배경에 맞게 조정)
  static const Color primarySoftDark = Color(0xFF1A2A40);

  /// 다크 프라이머리 서브틀
  static const Color primarySubtleDark = Color(0xFF141E2D);

  // ─────────────────────────────────────────────────────────────────
  // Secondary (보조 컬러)
  // ─────────────────────────────────────────────────────────────────

  /// 다크 보조 퍼플
  static const Color secondaryDark = Color(0xFF9B6DFF);

  /// 다크 보조 퍼플 소프트
  static const Color secondarySoftDark = Color(0xFF1F1A30);

  // ─────────────────────────────────────────────────────────────────
  // Feedback (피드백)
  // ─────────────────────────────────────────────────────────────────

  /// 다크 성공
  static const Color successDark = Color(0xFF22C55E);

  /// 다크 성공 소프트
  static const Color successSoftDark = Color(0xFF0D2818);

  /// 다크 경고
  static const Color warningDark = Color(0xFFFBBF24);

  /// 다크 경고 소프트
  static const Color warningSoftDark = Color(0xFF2D2510);

  /// 다크 위험
  static const Color dangerDark = Color(0xFFEF4444);

  /// 다크 위험 소프트
  static const Color dangerSoftDark = Color(0xFF2D1515);

  /// 다크 정보
  static const Color infoDark = Color(0xFF3C8DFF);

  /// 다크 정보 소프트
  static const Color infoSoftDark = Color(0xFF1A2A40);

  // ─────────────────────────────────────────────────────────────────
  // Interactive (상호작용)
  // ─────────────────────────────────────────────────────────────────

  /// 다크 링크
  static const Color linkDark = Color(0xFF3C8DFF);

  /// 다크 비활성 배경
  static const Color disabledDark = Color(0xFF2C3038);

  /// 다크 비활성 전경
  static const Color disabledForegroundDark = Color(0xFF6B7280);

  // ─────────────────────────────────────────────────────────────────
  // Skeleton & Overlay
  // ─────────────────────────────────────────────────────────────────

  /// 다크 스켈레톤 배경
  static const Color skeletonDark = Color(0xFF24272C);

  /// 다크 스켈레톤 하이라이트
  static const Color skeletonHighlightDark = Color(0xFF2E3136);

  /// 다크 오버레이
  static const Color overlayDark = Color(0xBF000000);

  /// 다크 라이트 오버레이
  static const Color overlayLightDark = Color(0x33000000);

  /// 다크 스낵바 배경
  static const Color snackbarSurfaceDark = Color(0xFF2C3038);

  // ─────────────────────────────────────────────────────────────────
  // Feature Specific Accents
  // ─────────────────────────────────────────────────────────────────

  /// 커뮤니티 스크랩 아이콘 (골드)
  static const Color communityScrapAccent = Color(0xFFC9AE58);

  /// 커뮤니티 일반 게시판 액센트
  static const Color communityBoardAccent = primary;
  static const Color communityBoardAccentSoft = primarySoft;

  /// 커뮤니티 질문 게시판 액센트 (오렌지)
  static const Color communityQuestionAccent = Color(0xFFFF9800);
  static const Color communityQuestionAccentSoft = Color(0xFFFFF3E0);

  /// 커뮤니티 투표 게시판 액센트 (앰버)
  static const Color communityVoteAccent = Color(0xFFFFC107);
  static const Color communityVoteAccentSoft = Color(0xFFFFF8E1);

  /// 패롯(프리미엄 재화) 색. 재화 식별 색이라 밝기에 따라 바뀌지 않는다.
  static const Color parrotCurrency = Color(0xFF10B981);

  /// 크래커(활동 재화) 색. 재화 식별 색이라 밝기에 따라 바뀌지 않는다.
  static const Color crackerCurrency = Color(0xFFF59E0B);

  // ─────────────────────────────────────────────────────────────────
  // AI & Brand Specific Accents
  // ─────────────────────────────────────────────────────────────────

  /// Gemini 모델 그라데이션 (파랑-보라-빨강)
  static const LinearGradient geminiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4285F4),
      Color(0xFF9B72CB),
      Color(0xFFD96570),
    ],
  );
}
