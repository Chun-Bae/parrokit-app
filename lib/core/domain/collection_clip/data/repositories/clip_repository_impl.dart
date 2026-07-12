// ============================================================================
// lib/core/collection_media/data/repositories/clip_repository_impl.dart
// ============================================================================
//
// [역할]
// ClipRepository 구현체. Clip CRUD + 가시성 조회를 담당하며, 썸네일/재생
// 파일 확보/목록 조립 등 세부 구현은 각 datasource에 위임합니다.
//
// [레이어]
// Core > Collection Media > Data > Repositories
// ============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/data/models/clip_view.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/domain/collection_clip/data/utils/clip_path_utils.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_source_ref_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_thumbnail_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_file_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_item_query_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_firestore_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_sync_coordinator.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/clip_repository.dart';

class ClipRepositoryImpl implements ClipRepository {
  final AppDatabase db;
  final ClipSourceRefDatasource sourceRefDatasource;
  final ClipThumbnailDatasource thumbnailDatasource;
  final ClipFileSyncDatasource fileSyncDatasource;
  final ClipItemQueryDatasource itemQueryDatasource;
  final ClipFirestoreMetadataDatasource firestoreMetadataDatasource;
  final LibraryEntitySyncCoordinator libraryEntitySyncCoordinator;

  ClipRepositoryImpl({
    required this.db,
    required this.sourceRefDatasource,
    required this.thumbnailDatasource,
    required this.fileSyncDatasource,
    required this.itemQueryDatasource,
    required this.firestoreMetadataDatasource,
    required this.libraryEntitySyncCoordinator,
  });

  @override
  Future<List<Clip>> getVisibleClipsForCollection(int? collectionId) async {
    final rows = await sourceRefDatasource.visibleClips();
    final filtered = rows.where((clip) {
      if (collectionId == null) return clip.collectionId == null;
      return clip.collectionId == collectionId;
    }).toList();
    filtered.sort((a, b) => a.id.compareTo(b.id));
    return filtered;
  }

  @override
  Future<List<Clip>> getVisibleClipsForCollections(
    List<int> collectionIds,
  ) async {
    final idSet = collectionIds.toSet();
    final rows = await sourceRefDatasource.visibleClips();
    final filtered = rows
        .where((clip) =>
            clip.collectionId != null && idSet.contains(clip.collectionId))
        .toList();
    filtered.sort((a, b) => a.id.compareTo(b.id));
    return filtered;
  }

  @override
  Future<List<Clip>> getVisibleClipsForStorageMode(String storageMode) async {
    final rows =
        await sourceRefDatasource.visibleClipsByStorageMode(storageMode);
    final sorted = [...rows]..sort((a, b) => a.id.compareTo(b.id));
    return sorted;
  }

  @override
  Future<int> countVisibleClipsInCollection(int collectionId) async {
    final clips = await getVisibleClipsForCollection(collectionId);
    return clips.length;
  }

  @override
  Future<ClipView?> fetchClipById(int clipId) async {
    final clip = await (db.select(db.clips)
          ..where((c) => c.id.equals(clipId))
          ..limit(1))
        .getSingleOrNull();
    if (clip == null) return null;

    if (!await sourceRefDatasource.isClipVisible(clip)) {
      return null;
    }

    final segments = await (db.select(db.segments)
          ..where((s) => s.clipId.equals(clip.id))
          ..orderBy([(s) => OrderingTerm.asc(s.startMs)]))
        .get();

    final abs = await fileSyncDatasource.ensurePlayableClipFile(clip);
    final clipAbs = clip.copyWith(filePath: abs);

    return ClipView(clip: clipAbs, segments: segments);
  }

  @override
  Future<bool> deleteClipById(int clipId) async {
    Clip? target;
    try {
      target = await (db.select(db.clips)
            ..where((c) => c.id.equals(clipId))
            ..limit(1))
          .getSingleOrNull();
      if (target == null) return false;

      final oldCollectionId = target.collectionId;

      final sourceRef =
          await sourceRefDatasource.getCurrentClipSourceRef(target);
      if (sourceRef != null) {
        await sourceRefDatasource.deleteRemoteLinkSource(sourceRef);
        if (sourceRef.provider == ClipStorageConstants.providerServer &&
            sourceRef.ownerScope == ClipStorageConstants.ownerScopeAppAccount) {
          await firestoreMetadataDatasource.deleteLibraryClipDoc(
              sourceRef.ownerKey, sourceRef.remoteDocId);
        }
      }

      final cacheEntries = await (db.select(db.clipCacheEntries)
            ..where((c) => c.clipId.equals(clipId)))
          .get();

      // 1. DB 삭제 트랜잭션
      await db.transaction(() async {
        await (db.delete(db.clipCacheEntries)
              ..where((c) => c.clipId.equals(clipId)))
            .go();
        await (db.delete(db.clipSourceRefs)
              ..where((c) => c.clipId.equals(clipId)))
            .go();
        await (db.delete(db.segments)..where((s) => s.clipId.equals(clipId)))
            .go();
        await (db.delete(db.clipTags)..where((ct) => ct.clipId.equals(clipId)))
            .go();
        await (db.delete(db.clips)..where((c) => c.id.equals(clipId))).go();
      });

      // 2. 고아 컬렉션 정리 (원격 동기화된 콜렉션이면 원격 문서도 함께 정리)
      if (oldCollectionId != null) {
        await _pruneCollectionIfEmpty(oldCollectionId);
      }

      // 3. 파일 삭제 (절대 경로 보정 후)
      final sourcePath = target.sourceFilePath ?? target.filePath;
      if (sourcePath.isNotEmpty) {
        try {
          final abs = await ClipPathUtils.absolutePathFor(sourcePath);
          final f = File(abs);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      for (final cacheEntry in cacheEntries) {
        try {
          final abs = await ClipPathUtils.absolutePathFor(cacheEntry.filePath);
          final f = File(abs);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> addMedia({
    required String? collectionName,
    required String clipTitle,
    required String filePath,
    required int durationMs,
    required List<Segment> segments,
    required List<String>? tags,
  }) async {
    final storageBytes = await ClipPathUtils.fileSizeFor(filePath);
    await db.transaction(() async {
      // 컬렉션 선택적 생성 (신규 클립은 항상 local로 시작하므로 local 스코프)
      int? collectionId;
      if (collectionName != null && collectionName.trim().isNotEmpty) {
        final col = await db.collectionsDao.findOrCreate(
          collectionName.trim(),
          ClipStorageConstants.storageModeLocal,
        );
        collectionId = col.id;
      }

      final clipId = await db.into(db.clips).insert(
            ClipsCompanion.insert(
              collectionId: Value(collectionId),
              title: clipTitle,
              filePath: filePath,
              sourceFilePath: Value(filePath),
              storageBytes: Value(storageBytes),
              durationMs: durationMs,
              ownerScope: const Value(ClipStorageConstants.ownerScopeDevice),
            ),
          );
      final thumbnailPath = await thumbnailDatasource.ensureThumbnailFile(
        clipId: clipId,
        videoPath: filePath,
      );
      if (thumbnailPath != null) {
        await (db.update(db.clips)..where((c) => c.id.equals(clipId))).write(
          ClipsCompanion(thumbnailFilePath: Value(thumbnailPath)),
        );
      }

      for (final s in segments) {
        await db.into(db.segments).insert(
              SegmentsCompanion.insert(
                clipId: clipId,
                startMs: s.startMs,
                endMs: s.endMs,
                original: s.original,
                pron: s.pron,
                trans: s.trans,
              ),
            );
      }

      if (tags != null) {
        for (final name in tags) {
          final tagId = await _ensureTag(name);
          await db.into(db.clipTags).insert(
                ClipTagsCompanion.insert(clipId: clipId, tagId: tagId),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
    });
  }

  @override
  Future<void> updateMedia({
    required int clipId,
    required String? collectionName,
    required String clipTitle,
    required String filePath,
    required int durationMs,
    required List<Segment> segments,
    required List<String>? tags,
    String? storageMode,
  }) async {
    // 이전 collectionId 확보
    final prevClip = await (db.select(db.clips)
          ..where((c) => c.id.equals(clipId)))
        .getSingle();
    final oldCollectionId = prevClip.collectionId;

    await db.transaction(() async {
      // 새 컬렉션 결정 (클립의 현재 storageMode에 맞는 콜렉션으로 스코프)
      int? newCollectionId;
      if (collectionName != null && collectionName.trim().isNotEmpty) {
        final col = await db.collectionsDao
            .findOrCreate(collectionName.trim(), prevClip.storageMode);
        newCollectionId = col.id;
      }
      final thumbnailPath = await thumbnailDatasource.ensureThumbnailFile(
        clipId: clipId,
        videoPath: filePath,
        existingThumbnailPath: prevClip.thumbnailFilePath,
      );

      // 클립 갱신
      await (db.update(db.clips)..where((c) => c.id.equals(clipId))).write(
        ClipsCompanion(
          collectionId: Value(newCollectionId),
          title: Value(clipTitle),
          filePath: Value(filePath),
          sourceFilePath: Value(filePath),
          thumbnailFilePath: Value(thumbnailPath),
          storageBytes: Value(await ClipPathUtils.fileSizeFor(filePath)),
          durationMs: Value(durationMs),
          storageMode:
              storageMode == null ? const Value.absent() : Value(storageMode),
        ),
      );

      // 세그먼트 재작성 (Full replace)
      await (db.delete(db.segments)..where((s) => s.clipId.equals(clipId)))
          .go();
      for (final s in segments) {
        await db.into(db.segments).insert(
              SegmentsCompanion.insert(
                clipId: clipId,
                startMs: s.startMs,
                endMs: s.endMs,
                original: s.original,
                pron: s.pron,
                trans: s.trans,
              ),
            );
      }

      // 태그 갱신
      if (tags != null) {
        await (db.delete(db.clipTags)..where((ct) => ct.clipId.equals(clipId)))
            .go();
        for (final name in tags.toSet()) {
          final tagId = await _ensureTag(name);
          await db.into(db.clipTags).insert(
                ClipTagsCompanion.insert(clipId: clipId, tagId: tagId),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
    });

    // 이전 컬렉션 고아 정리 (트랜잭션 밖에서, 원격 문서도 함께 정리)
    if (oldCollectionId != null) {
      await _pruneCollectionIfEmpty(oldCollectionId);
    }
  }

  /// 클립이 빠져나간 콜렉션에 더 이상 클립이 없으면 콜렉션을 지운다.
  /// 원격에 동기화된 콜렉션(server/gdrive)이면 원격 문서도 함께 지워야
  /// 다음 pull 동기화 때 빈 콜렉션이 다시 살아나지 않는다.
  Future<void> _pruneCollectionIfEmpty(int collectionId) async {
    final remainingClips = await (db.select(db.clips)
          ..where((c) => c.collectionId.equals(collectionId)))
        .get();
    if (remainingClips.isNotEmpty) return;

    await libraryEntitySyncCoordinator.deleteCollection(collectionId);
    await db.collectionsDao.pruneIfEmpty(collectionId);
  }

  @override
  Future<List<ClipItem>> fetchClipItemsByStorageMode(String storageMode) {
    return itemQueryDatasource.fetchClipItemsByStorageMode(storageMode);
  }

  @override
  Future<List<ClipItem>> fetchCachedRemoteClipItems() {
    return itemQueryDatasource.fetchCachedRemoteClipItems();
  }

  @override
  Future<Uint8List?> loadThumbnailBytes(Clip clip) {
    return thumbnailDatasource.loadThumbnailBytes(clip);
  }

  Future<int> _ensureTag(String name) async {
    final found = await (db.select(db.tags)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    if (found != null) return found.id;
    return db.into(db.tags).insert(
          TagsCompanion.insert(
            name: name,
          ),
        );
  }
}
