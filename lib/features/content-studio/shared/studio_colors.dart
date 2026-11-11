import 'package:flutter/material.dart';

/// 콘텐츠 제작(content-studio) 기능 고유의 브랜드 색.
///
/// 앱 테마 색이 아니라 챗봇 모드와 AI 공급자를 구분하는 색이므로
/// AppTokens가 아니라 여기에 모아 둔다. 라이트/다크에 따라 바뀌지 않는다.
/// 앱 전역 색이 필요하면 `AppTokens.of(context)`나 `AppColors`를 쓴다.
abstract final class StudioColors {
  // ── 챗봇 모드 식별 색 ──────────────────────────────────────────
  /// 일반 대화 모드.
  static const Color generalPurple = Color(0xFF8B5CF6);

  /// 음성(TTS) 모드.
  static const Color ttsPink = Color(0xFFEC4899);

  /// 영상 모드.
  static const Color videoBlue = Color(0xFF3B82F6);

  // ── 그라디언트에서 짝으로 쓰는 색 ─────────────────────────────
  /// 보라 계열 그라디언트의 밝은 끝.
  static const Color purpleLight = Color(0xFFC084FC);

  /// 영상 모드 그라디언트의 청록 끝.
  static const Color videoCyan = Color(0xFF06B6D4);

  /// 추천 액션 칩 그라디언트의 하늘색 끝.
  static const Color actionCyan = Color(0xFF00C6FF);

  // ── AI 공급자 브랜드 색 ───────────────────────────────────────
  /// Gemini 음성 선택에 쓰는 보라.
  static const Color geminiPurple = Color(0xFF9B72CB);
}
