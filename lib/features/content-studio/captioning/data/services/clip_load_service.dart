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
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_detail_query_datasource.dart';
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
    // 예전에는 clipProvider.clips·collections·tagsByClip(예전 보관함 화면이
    // 고른 폴더에서만 채우는 목록)에서 찾았다. 새 보관함·플레이어에서 열면
    // 이 목록이 비어 있어 '편집할 클립을 찾을 수 없습니다'로 늘 실패했다(5차).
    // DB에서 직접 읽는다.
    final clipView = await clipProvider.fetchClipById(clipId);
    if (clipView == null) {
      throw Exception('편집할 클립을 찾을 수 없습니다.');
    }
    final clip = clipView.clip;

    String? collectionName;
    final collectionId = clip.collectionId;
    if (collectionId != null) {
      collectionName =
          (await clipProvider.db.collectionsDao.findById(collectionId))?.name;
    }

    final tagList =
        await ClipDetailQueryDatasource(clipProvider.db).tagNamesForClip(clipId);

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

    // 저장할 때 영상을 바꾸지 않았으면 DB에 있던 경로를 그대로 둔다. 예전엔
    // 재생용 절대경로(resolvedFilePath)를 넘겨 저장이 그 값을 DB에 썼고, 앱을
    // 다시 설치·업데이트해 앱 폴더 경로가 바뀌면 '로컬 파일을 찾을 수 없습니다'가
    // 됐다(5차). 서버·Drive 클립은 빈 값 그대로다.
    final stored = await (clipProvider.db.select(clipProvider.db.clips)
          ..where((c) => c.id.equals(clipId))
          ..limit(1))
        .getSingleOrNull();

    return LoadClipResult(
      formData: formData,
      mode: EditMode(clipId: clipId, existingFilePath: stored?.filePath ?? ''),
      rawSegments: clipView.segments,
    );
  }
}
