// ============================================================================
// lib/features/_content/clip_editor/data/services/clip_save_service.dart
// ============================================================================
//
// [역할]
// 클립 저장 서비스.
//
// [레이어]
// Data Layer > Services
// ============================================================================

import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart' as db;

import '../../domain/models/clip_form_data.dart';
import '../../domain/models/edit_mode.dart';
import '../../domain/utils/timecode_service.dart';
import 'file_staging_service.dart';

/// 클립 저장 서비스.
class ClipSaveService {
  final ClipProvider repo;
  final FileStagingService staging;
  final TimecodeService _timecode = TimecodeService();

  ClipSaveService({required this.repo, required this.staging});

  /// ClipFormData와 EditModeBase를 사용하여 클립을 저장합니다.
  Future<void> save({
    required ClipFormData formData,
    required EditModeBase mode,
    required String stagedFilePath,
  }) async {
    // 파일 경로 결정
    String relPath;
    if (mode is EditMode &&
        mode.existingFilePath != null &&
        !staging.isInStaging(stagedFilePath)) {
      // 영상을 바꾸지 않은 편집: DB에 있던 경로 그대로(서버·Drive 클립은 빈 값).
      relPath = mode.existingFilePath!;
    } else {
      relPath = await staging.finalize(stagedFilePath);
    }

    // SegmentInput -> db.Segment 변환
    final segments = formData.segments
        .map((s) => db.Segment(
              id: 0,
              clipId: 0,
              startMs: _timecode.parseToMs(s.start),
              endMs: _timecode.parseToMs(s.end),
              original: s.original,
              pron: s.pron,
              trans: s.ko,
            ))
        .toList();

    if (mode is EditMode) {
      await repo.updateClip(
        clipId: mode.clipId,
        collectionName: formData.collectionName,
        clipTitle: formData.clipTitle,
        filePath: relPath,
        durationMs: formData.durationMs!,
        segments: segments,
        tags: formData.tags,
      );
    } else {
      await repo.addClip(
        collectionName: formData.collectionName,
        clipTitle: formData.clipTitle,
        filePath: relPath,
        durationMs: formData.durationMs!,
        segments: segments,
        tags: formData.tags,
      );
    }
  }
}
