// ============================================================================
// lib/features/_content/clip_editor/data/adapters/asr_engine.dart
// ============================================================================
//
// [역할]
// 사용자가 선택 가능한 ASR 엔진 enum.
//
// [레이어]
// Data Layer > Adapters
// ============================================================================

/// ASR(STT) 엔진 종류.
enum AsrEngine {
  /// whisper-1. 무음/긴 파일에 안정적, 화자 분리 없음.
  whisper,
}

extension AsrEngineLabel on AsrEngine {
  String get label => switch (this) {
        AsrEngine.whisper => '안정 (Whisper)',
      };

  String get description => switch (this) {
        AsrEngine.whisper => '무음이 많거나 긴 파일에 안정적',
      };
}
