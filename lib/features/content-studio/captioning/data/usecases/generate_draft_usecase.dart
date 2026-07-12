// ============================================================================
// lib/features/_content/clip_editor/data/usecases/generate_draft_usecase.dart
// ============================================================================
//
// [역할]
// STT 및 LLM을 사용하여 세그먼트 초안을 생성하는 UseCase.
// 실제 로직은 주입된 CaptionDraftGenerator(RemoteCaptionDraftService)에 위임.
//
// [레이어]
// Data Layer > UseCases
// ============================================================================

import '../ports/caption_draft_port.dart';

export '../ports/caption_draft_port.dart' show DraftResult;

/// STT + LLM 초안 생성 UseCase.
class GenerateDraftUseCase {
  final CaptionDraftGenerator _service;

  GenerateDraftUseCase({required CaptionDraftGenerator service})
      : _service = service;

  /// 영상 파일에서 STT를 수행하고 번역/발음 초안을 생성합니다.
  Future<DraftResult> call({
    required String filePath,
    required int durationMs,
    String language = 'ja',
    void Function(int current, int total, String message)? onProgress,
  }) =>
      _service.generate(
        filePath: filePath,
        durationMs: durationMs,
        language: language,
        onProgress: onProgress,
      );
}
