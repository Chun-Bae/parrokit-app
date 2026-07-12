// ============================================================================
// lib/features/_content/clip_editor/data/services/clip_load_service.dart
// ============================================================================
//
// [역할]
// 편집용 클립 데이터 로드 서비스.
//
// [레이어]
// Data Layer > Services
// ============================================================================

import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart' as db;
import 'package:parrokit/features/content-studio/captioning/domain/models/clip_form_data.dart';
import 'package:parrokit/features/content-studio/captioning/domain/models/edit_mode.dart';
import 'package:parrokit/features/content-studio/captioning/domain/utils/timecode_service.dart';

/// 편집용 클립 로드 결과.
class LoadClipResult {
  final ClipFormData formData;
  final EditMode mode;
  final List<db.Segment> rawSegments;

  const LoadClipResult({
    required this.formData,
    required this.mode,
    required this.rawSegments,
  });
}

/// 편집용 클립 데이터 로드 서비스.
class ClipLoadService {
  final ClipProvider clipProvider;
  final TimecodeService _timecode = TimecodeService();

  ClipLoadService({required this.clipProvider});

  /// 클립 ID로 편집 데이터를 로드합니다.
  Future<LoadClipResult> loadForEdit(int clipId) async {
    // 클립 조회
    final db.Clip clip;
    try {
      clip = clipProvider.clips.firstWhere((c) => c.id == clipId);
    } catch (_) {
      throw Exception('편집할 클립을 찾을 수 없습니다.');
    }

    // 컬렉션 이름 조회 (collectionId가 있는 경우)
    String? collectionName;
    if (clip.collectionId != null) {
      final collection =
          clipProvider.collections.cast<db.Collection?>().firstWhere(
                (c) => c?.id == clip.collectionId,
                orElse: () => null,
              );
      collectionName = collection?.name;
    }

    // 태그 조회
    final tagList = (clipProvider.tagsByClip[clipId] ?? const <db.Tag>[])
        .map((t) => t.name)
        .toList();

    // 세그먼트 조회
    final clipView = await clipProvider.fetchClipById(clipId);
    if (clipView == null) {
      throw Exception('편집할 클립을 찾을 수 없습니다.');
    }

    // SegmentInput으로 변환
    final segmentInputs = clipView.segments
        .map((s) => SegmentInput(
              start: _timecode.msToMMSSmmm(s.startMs),
              end: _timecode.msToMMSSmmm(s.endMs),
              original: s.original,
              pron: s.pron,
              ko: s.trans,
            ))
        .toList();

    // ClipFormData 생성. 서버/gdrive 클립은 clip.filePath가 비어 있고
    // (원본 파일이 로컬에 없다는 뜻), fetchClipById가 반환하는
    // clipView.clip.filePath만 캐시에서 복구된 재생 가능한 절대 경로다.
    final resolvedFilePath = clipView.clip.filePath;
    final formData = ClipFormData(
      collectionName: collectionName,
      clipTitle: clip.title,
      durationMs: clip.durationMs > 0 ? clip.durationMs : null,
      segments: segmentInputs,
      tags: tagList,
      filePath: resolvedFilePath,
    );

    return LoadClipResult(
      formData: formData,
      mode: EditMode(clipId: clipId, existingFilePath: resolvedFilePath),
      rawSegments: clipView.segments,
    );
  }
}
