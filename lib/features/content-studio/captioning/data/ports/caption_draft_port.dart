// ============================================================================
// lib/features/content-studio/captioning/data/ports/caption_draft_port.dart
// ============================================================================
//
// [역할]
// 자동 자막 초안 생성 포트 인터페이스.
// DraftResult DTO 및 CaptionDraftGenerator 추상 클래스 정의.
// 실제 구현은 RemoteCaptionDraftService.
//
// [레이어]
// Data Layer > Ports
// ============================================================================

import '../../domain/models/clip_form_data.dart';

/// 초안 생성 결과.
class DraftResult {
  final List<SegmentInput> segments;
  final int coinCost;

  const DraftResult({
    required this.segments,
    required this.coinCost,
  });
}

/// STT + 번역 초안 생성 서비스 공통 인터페이스.
abstract class CaptionDraftGenerator {
  Future<DraftResult> generate({
    required String filePath,
    required int durationMs,
    String language = 'ja',
    void Function(int current, int total, String message)? onProgress,
  });
}
