// ============================================================================
// lib/core/state/provider/mixins/clip_action_mixin.dart
// ============================================================================
//
// [역할]
// 클립 CRUD 및 액션 로직 분리 (Mixin)
//
// [레이어]
// Core > State > Provider > Mixins
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import '../../../../../data/local/app_database.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/clip_repository.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/clip_migration_repository.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_sync_coordinator.dart';

mixin ClipActionMixin on ChangeNotifier {
  AppDatabase get db;
  ClipRepository get service;
  ClipMigrationRepository get migrationService;
  LibraryEntitySyncCoordinator get libraryEntitySyncCoordinator;

  // Navigation / Refresh required methods
  int? get selectedGroupId;
  int? get selectedCollectionId;

  Future<void> selectGroup(int? id);
  Future<void> selectCollection(int? id);
  Future<void> loadGroups();
  Future<void> loadCollections();
  Future<void> refreshStorageUsage();

  // ─────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────

  Future<bool> deleteClipById(int clipId) async {
    final success = await service.deleteClipById(clipId);
    if (!success) return false;

    // Refresh current view
    if (selectedCollectionId == -1) {
      // "모든 클립"/"그룹 내 모든 클립" 가상 뷰: 실제 콜렉션이 아니므로
      // 존재 여부를 조회할 필요 없이 같은 가상 뷰를 다시 불러온다.
      await selectCollection(-1);
      return true;
    }

    if (selectedCollectionId != null) {
      final exists = await (db.select(db.collections)
            ..where((c) => c.id.equals(selectedCollectionId!))
            ..limit(1))
          .getSingleOrNull();
      if (exists != null) {
        await selectCollection(selectedCollectionId);
        return true;
      }
    }

    await selectGroup(selectedGroupId);
    return true;
  }

  Future<bool> deleteCollectionById(int collectionId) async {
    final clipsInCol = await (db.select(db.clips)
          ..where((c) => c.collectionId.equals(collectionId)))
        .get();

    for (final clip in clipsInCol) {
      await service.deleteClipById(clip.id);
    }

    await libraryEntitySyncCoordinator.deleteCollection(collectionId);
    // group_collections가 이 콜렉션을 참조하는 채로 두면 FK 제약(ON DELETE
    // 지정 없음) 때문에 아래 delete가 예외를 던진다.
    await (db.delete(db.groupCollections)
          ..where((gc) => gc.collectionId.equals(collectionId)))
        .go();
    await (db.delete(db.collections)..where((c) => c.id.equals(collectionId)))
        .go();

    await selectGroup(selectedGroupId);
    return true;
  }

  Future<void> addClip({
    required String? collectionName,
    required String clipTitle,
    required String filePath,
    required int durationMs,
    required List<Segment> segments,
    required List<String>? tags,
  }) async {
    await service.addMedia(
      collectionName: collectionName,
      clipTitle: clipTitle,
      filePath: filePath,
      durationMs: durationMs,
      segments: segments,
      tags: tags,
    );
    await refreshStorageUsage();
    notifyListeners();
  }

  Future<void> updateClip({
    required int clipId,
    required String? collectionName,
    required String clipTitle,
    required String filePath,
    required int durationMs,
    required List<Segment> segments,
    required List<String>? tags,
    String? storageMode,
  }) async {
    await service.updateMedia(
      clipId: clipId,
      collectionName: collectionName,
      clipTitle: clipTitle,
      filePath: filePath,
      durationMs: durationMs,
      segments: segments,
      tags: tags,
      storageMode: storageMode,
    );
    await refreshStorageUsage();
    notifyListeners();
  }

  Future<bool> moveClipToServer(int clipId) async {
    try {
      await migrationService.moveClipToServer(clipId);
      await refreshStorageUsage();
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] move-to-server failed clipId=$clipId',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<bool> moveClipToGoogleDrive(int clipId) async {
    try {
      await migrationService.moveClipToGoogleDrive(clipId);
      await refreshStorageUsage();
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] move-to-gdrive failed clipId=$clipId',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<bool> moveClipToLocal(int clipId) async {
    try {
      await migrationService.moveClipToLocal(clipId);
      await refreshStorageUsage();
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] move-to-local failed clipId=$clipId',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<bool> clearRemoteClipCache(int clipId) async {
    try {
      final success = await migrationService.clearRemoteClipCache(clipId);
      await refreshStorageUsage();
      notifyListeners();
      return success;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Cache] clear-cache failed clipId=$clipId',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
