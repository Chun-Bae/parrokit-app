// lib/core/theme/app_radius.dart
//
// 앱 전역 둥글기 시스템 - 일관된 border radius 적용

/// 앱 전역 둥글기 상수
///
/// 컴포넌트 크기에 따른 적절한 둥글기 제공
abstract final class AppRadius {
  // ─────────────────────────────────────────────────────────────────
  // Base Radius Values
  // ─────────────────────────────────────────────────────────────────

  /// 없음 (0dp)
  static const double none = 0;

  /// 초극소 (2dp) - 진행 막대, 슬라이더 레일, 시트 드래그 핸들 같은 얇은 바
  static const double xxs = 2;

  /// 극소 (4dp) - 작은 뱃지, 태그
  static const double xs = 4;

  /// 소 (8dp) - 칩, 토글
  static const double sm = 8;

  /// 중 (12dp) - 카드, 입력필드
  static const double md = 12;

  /// 대 (16dp) - 다이얼로그, 바텀시트
  static const double lg = 16;

  /// 특대 (20dp) - 모달
  static const double xl = 20;

  /// 극대 (24dp) - 큰 컨테이너
  static const double xxl = 24;

  /// 완전 둥근 (999dp) - 버튼, 필
  static const double full = 999;

  // ─────────────────────────────────────────────────────────────────
  // Semantic Aliases
  // ─────────────────────────────────────────────────────────────────

  /// 버튼 (40dp → full)
  static const double button = full;

  /// 입력필드 (12dp)
  static const double input = md;

  /// 카드 (12dp)
  static const double card = md;

  /// 칩 (40dp)
  static const double chip = full;

  /// 다이얼로그 (16dp)
  static const double dialog = lg;

  /// 바텀시트 상단 (20dp)
  static const double bottomSheet = xl;

  /// 썸네일 (8dp)
  static const double thumbnail = sm;

  /// 얇은 바 (2dp) - 진행 막대와 드래그 핸들
  static const double track = xxs;
}
