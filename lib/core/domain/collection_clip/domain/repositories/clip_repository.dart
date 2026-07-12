// ============================================================================
// lib/core/collection_media/domain/repositories/clip_repository.dart
// ============================================================================
//
// [역할]
// Clip 기본 CRUD 및 조회를 위한 추상 계약(Repository 인터페이스).
// local/server/gdrive 간 이동(moveClipTo*)과 저장 용량·계정 조회는
// ClipMigrationRepository를 사용하세요.
//
// [레이어]
// Core > Collection Media > Domain > Repositories
// ============================================================================

import 'dart:typed_data';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/data/models/clip_view.dart';

abstract class ClipRepository {
  /// Clip ID로 단일 클립 정보(세그먼트 포함) 조회.
  Future<ClipView?> fetchClipById(int clipId);

  /// Clip 삭제 (파일 및 고아 컬렉션 정리 포함).
  Future<bool> deleteClipById(int clipId);

  /// 미디어 추가 (Collection 선택적 생성 + Clip 삽입).
  Future<void> addMedia({
    required String? collectionName,
    required String clipTitle,
    required String filePath,
    required int durationMs,
    required List<Segment> segments,
    required List<String>? tags,
  });

  /// 미디어 정보 수정 (컬렉션 변경 + 고아 컬렉션 정리 포함).
  Future<void> updateMedia({
    required int clipId,
    required String? collectionName,
    required String clipTitle,
    required String filePath,
    required int durationMs,
    required List<Segment> segments,
    required List<String>? tags,
    String? storageMode,
  });

  /// 컬렉션에 속한(현재 보이는) 클립 목록 조회. collectionId가 null이면
  /// 컬렉션 미지정 클립을 반환합니다.
  Future<List<Clip>> getVisibleClipsForCollection(int? collectionId);

  /// 주어진 콜렉션들(collectionIds)에 속한 클립을 모두 합쳐서 반환합니다.
  /// "그룹 내 모든 클립" 가상 뷰에서 사용합니다.
  Future<List<Clip>> getVisibleClipsForCollections(List<int> collectionIds);

  /// 특정 저장위치의 모든 클립(콜렉션 소속 여부 무관)을 반환합니다.
  /// "모든 클립" 가상 뷰에서 사용합니다.
  Future<List<Clip>> getVisibleClipsForStorageMode(String storageMode);

  Future<int> countVisibleClipsInCollection(int collectionId);

  Future<List<ClipItem>> fetchClipItemsByStorageMode(String storageMode);

  Future<List<ClipItem>> fetchCachedRemoteClipItems();

  /// clip.thumbnailFilePath(로컬 캐시) -> 원격(server/gdrive) 순으로 썸네일
  /// 바이트를 복구합니다. 화면단은 항상 이 메서드를 사용해야 하며, 직접
  /// VideoThumbnail을 호출해 재구현하지 않아야 합니다.
  Future<Uint8List?> loadThumbnailBytes(Clip clip);
}
