// ============================================================================
// lib/features/_content/clip_editor/data/constants/openai_constants.dart
// ============================================================================
//
// [역할]
// OpenAI API 관련 상수 정의.
// API 엔드포인트, 기본 모델명 등.
//
// [레이어]
// Data Layer > Constants
// ============================================================================

/// OpenAI API 상수.
class OpenAIConstants {
  OpenAIConstants._();

  // ─────────────────────────────────────────────────────────────────
  // Chat Completions API
  // ─────────────────────────────────────────────────────────────────
  static const chatEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const chatDefaultModel = 'gpt-4o-mini';

  // ─────────────────────────────────────────────────────────────────
  // Audio Transcriptions API (ASR/STT)
  // ─────────────────────────────────────────────────────────────────
  static const asrEndpoint = 'https://api.openai.com/v1/audio/transcriptions';
}
