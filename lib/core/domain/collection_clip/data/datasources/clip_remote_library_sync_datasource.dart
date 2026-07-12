// ============================================================================
// lib/core/collection_media/data/datasources/clip_remote_library_sync_datasource.dart
// ============================================================================
//
// [역할]
// 계정의 서버(Firestore)/클라우드(Google Drive) 클립 목록을 조회해서, 이
// 기기 로컬 DB에 아직 없는 클립을 찾아 로컬에 반영(pull sync)하는
// datasource. 다른 기기에서 서버/클라우드로 옮긴 클립을 이 기기에서도
// 보이게 하기 위한 용도입니다.
//
// [레이어]
// Core > Collection Media > Data > Datasources
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/domain/collection_clip/data/utils/clip_path_utils.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'clip_firestore_metadata_datasource.dart';
import 'clip_source_ref_datasource.dart';
import 'library_entity_sync_coordinator.dart';

class ClipRemoteLibrarySyncDatasource {
  final AppDatabase db;
  final ClipFirestoreMetadataDatasource firestoreMetadataDatasource;
  final ClipSourceRefDatasource sourceRefDatasource;
  final GoogleDriveStorageService googleDriveStorageService;
  final LibraryEntitySyncCoordinator libraryEntitySyncCoordinator;

  ClipRemoteLibrarySyncDatasource(
    this.db,
    this.firestoreMetadataDatasource,
    this.sourceRefDatasource,
    this.googleDriveStorageService,
    this.libraryEntitySyncCoordinator,
  );

  /// [uid] 계정의 서버 클립 중 이 기기에 없는 것을 로컬로 받아옵니다.
  /// 새로 반영된 클립 개수를 반환합니다.
  Future<int> pullServerClips(String uid) async {
    final snapshot = await firestoreMetadataDatasource.libraryClipsRef(uid).get();
    AppLogger.i(
      '[Clip][RemoteSync] server-pull start uid=$uid docs=${snapshot.docs.length}',
    );
    var pulledCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final remoteDocId = data['remoteDocId'] as String? ?? doc.id;
      final existingClipId = await _findLocalClipId(
        provider: ClipStorageConstants.providerServer,
        ownerKey: uid,
        remoteDocId: remoteDocId,
      );
      if (existingClipId != null) {
        final backfilled = await _backfillUncategorizedIfNeeded(
          existingClipId,
          ClipStorageConstants.storageModeServer,
        );
        if (backfilled) pulledCount++;
        continue;
      }

      final clipId = await _insertClipRow(
        data: data,
        storageMode: ClipStorageConstants.storageModeServer,
        ownerScope: ClipStorageConstants.ownerScopeAppAccount,
        ownerKey: uid,
      );
      await sourceRefDatasource.upsertClipSourceRef(
        clipId: clipId,
        provider: ClipStorageConstants.providerServer,
        ownerScope: ClipStorageConstants.ownerScopeAppAccount,
        ownerKey: uid,
        remoteDocId: remoteDocId,
        storagePath: data['storagePath'] as String?,
        downloadUrl: data['downloadUrl'] as String?,
        thumbnailStoragePath: data['thumbnailStoragePath'] as String?,
        thumbnailDownloadUrl: data['thumbnailDownloadUrl'] as String?,
        lastSyncedAt: DateTime.now(),
      );
      await _insertSegments(clipId, data['segments']);
      await _insertTags(clipId, data['tags']);
      pulledCount++;
    }

    AppLogger.i('[Clip][RemoteSync] server-pull done pulled=$pulledCount');
    return pulledCount;
  }

  /// [accountKey](gdrive 계정) 소유 클립 중 이 기기에 없는 것을 로컬로
  /// 받아옵니다. 새로 반영된 클립 개수를 반환합니다.
  Future<int> pullCloudClips(String accountKey) async {
    final clipFolders = await googleDriveStorageService.listClipFolders();
    AppLogger.i(
      '[Clip][RemoteSync] cloud-pull start accountKey=$accountKey folders=${clipFolders.length}',
    );
    var pulledCount = 0;

    for (final (remoteDocId, folderId) in clipFolders) {
      final existingClipId = await _findLocalClipId(
        provider: ClipStorageConstants.providerGoogleDrive,
        ownerKey: accountKey,
        remoteDocId: remoteDocId,
      );
      if (existingClipId != null) {
        AppLogger.d('[Clip][RemoteSync] cloud-pull skip-existing remoteDocId=$remoteDocId');
        final backfilled = await _backfillUncategorizedIfNeeded(
          existingClipId,
          ClipStorageConstants.storageModeGoogleDrive,
        );
        if (backfilled) pulledCount++;
        continue;
      }

      final files = await googleDriveStorageService.listFilesInFolder(folderId);
      final metadataFileId = files['metadata.json'];
      if (metadataFileId == null) {
        AppLogger.w(
          '[Clip][RemoteSync] cloud-pull skip-no-metadata remoteDocId=$remoteDocId files=${files.keys.toList()}',
        );
        continue;
      }
      final data = await _downloadJsonMap(metadataFileId);
      if (data == null) {
        AppLogger.w(
          '[Clip][RemoteSync] cloud-pull skip-bad-metadata remoteDocId=$remoteDocId',
        );
        continue;
      }

      // metadata.json은 있지만 실제 영상 파일이 없는 폴더는, 예전에 이동/
      // 삭제 중 일부 파일만 지워지고 남은 고아 폴더다. 이런 폴더까지
      // 클립으로 만들면 같은 클립이 두 개로 보이는 원인이 되므로, 건너뛰고
      // 폴더 자체를 정리한다.
      final videoFileName = _fileNameFromPath(data['storagePath'] as String?);
      final videoFileId = videoFileName == null ? null : files[videoFileName];
      if (videoFileId == null) {
        AppLogger.w(
          '[Clip][RemoteSync] cloud-pull skip-orphan-no-video remoteDocId=$remoteDocId files=${files.keys.toList()}',
        );
        await googleDriveStorageService.deleteFile(folderId);
        continue;
      }

      final clipId = await _insertClipRow(
        data: data,
        storageMode: ClipStorageConstants.storageModeGoogleDrive,
        ownerScope: ClipStorageConstants.ownerScopeCloudAccount,
        ownerKey: accountKey,
      );
      await sourceRefDatasource.upsertClipSourceRef(
        clipId: clipId,
        provider: ClipStorageConstants.providerGoogleDrive,
        ownerScope: ClipStorageConstants.ownerScopeCloudAccount,
        ownerKey: accountKey,
        remoteDocId: remoteDocId,
        storagePath: data['storagePath'] as String?,
        remoteFileId: videoFileId,
        thumbnailStoragePath: data['thumbnailStoragePath'] as String?,
        thumbnailRemoteFileId:
            files[_fileNameFromPath(data['thumbnailStoragePath'] as String?)],
        cloudFolderId: folderId,
        metadataPath: 'clips/$remoteDocId/metadata.json',
        lastSyncedAt: DateTime.now(),
      );
      await _insertSegments(clipId, data['segments']);
      await _insertTags(clipId, data['tags']);
      pulledCount++;
    }

    // Drive가 source of truth. 이번에 조회한 폴더 목록에 없는 로컬 gdrive
    // 클립은 Drive에서 직접(앱 밖에서) 지워진 것이므로 그대로 정리한다.
    final remoteFolderIds = clipFolders.map((f) => f.$1).toSet();
    pulledCount += await _pruneLocalClipsGoneFromCloud(
      accountKey: accountKey,
      remoteFolderIds: remoteFolderIds,
    );

    AppLogger.i('[Clip][RemoteSync] cloud-pull done pulled=$pulledCount');
    return pulledCount;
  }

  /// [accountKey] 소유의 gdrive 클립 중, 이번에 조회한 Drive 폴더 목록에
  /// 더 이상 없는 것을 찾아 로컬에서 정리합니다(캐시 파일 포함). 정리한
  /// 클립 개수를 반환합니다.
  Future<int> _pruneLocalClipsGoneFromCloud({
    required String accountKey,
    required Set<String> remoteFolderIds,
  }) async {
    final localRefs = await (db.select(db.clipSourceRefs)
          ..where(
            (r) =>
                r.provider.equals(ClipStorageConstants.providerGoogleDrive) &
                r.ownerKey.equals(accountKey),
          ))
        .get();

    var removedCount = 0;
    for (final ref in localRefs) {
      if (remoteFolderIds.contains(ref.remoteDocId)) continue;
      AppLogger.i(
        '[Clip][RemoteSync] cloud-pull remote-gone clipId=${ref.clipId} remoteDocId=${ref.remoteDocId}',
      );
      final removed = await _deleteLocalClip(ref.clipId);
      if (removed) removedCount++;
    }
    return removedCount;
  }

  /// 원격에 이미 없는 클립의 로컬 흔적(DB 행, 캐시 파일)만 정리합니다.
  /// 원격 삭제는 시도하지 않습니다 — 애초에 원격에 없어서 호출된 경로라
  /// deleteFile을 다시 불러도 404만 돌아옵니다.
  Future<bool> _deleteLocalClip(int clipId) async {
    final target = await (db.select(db.clips)
          ..where((c) => c.id.equals(clipId))
          ..limit(1))
        .getSingleOrNull();
    if (target == null) return false;

    final oldCollectionId = target.collectionId;
    final cacheEntries = await (db.select(db.clipCacheEntries)
          ..where((c) => c.clipId.equals(clipId)))
        .get();

    await db.transaction(() async {
      await (db.delete(db.clipCacheEntries)..where((c) => c.clipId.equals(clipId)))
          .go();
      await (db.delete(db.clipSourceRefs)..where((c) => c.clipId.equals(clipId)))
          .go();
      await (db.delete(db.segments)..where((s) => s.clipId.equals(clipId))).go();
      await (db.delete(db.clipTags)..where((ct) => ct.clipId.equals(clipId))).go();
      await (db.delete(db.clips)..where((c) => c.id.equals(clipId))).go();
    });

    if (oldCollectionId != null) {
      await _pruneCollectionIfEmpty(oldCollectionId);
    }

    for (final cacheEntry in cacheEntries) {
      try {
        final abs = await ClipPathUtils.absolutePathFor(cacheEntry.filePath);
        final file = File(abs);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    return true;
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

  /// 이 기기에 이미 있는 클립이면 그 clipId를, 없으면 null을 반환합니다.
  Future<int?> _findLocalClipId({
    required String provider,
    required String ownerKey,
    required String remoteDocId,
  }) async {
    final existing = await (db.select(db.clipSourceRefs)
          ..where(
            (r) =>
                r.remoteDocId.equals(remoteDocId) &
                r.provider.equals(provider) &
                r.ownerKey.equals(ownerKey),
          )
          ..limit(1))
        .getSingleOrNull();
    return existing?.clipId;
  }

  /// 예전 버전에서 콜렉션 정보 없이 당겨온 클립(collectionId=null)을
  /// "미분류" 콜렉션으로 채워 넣습니다. 실제로 채워 넣었으면 true를
  /// 반환합니다.
  Future<bool> _backfillUncategorizedIfNeeded(int clipId, String storageMode) async {
    final clip = await (db.select(db.clips)
          ..where((c) => c.id.equals(clipId))
          ..limit(1))
        .getSingleOrNull();
    if (clip == null || clip.collectionId != null) return false;

    final collectionId = await _resolveCollectionId(null, storageMode);
    await (db.update(db.clips)..where((c) => c.id.equals(clipId))).write(
      ClipsCompanion(collectionId: Value(collectionId)),
    );
    return true;
  }

  Future<int> _insertClipRow({
    required Map<String, dynamic> data,
    required String storageMode,
    required String ownerScope,
    required String ownerKey,
  }) async {
    final collectionId = await _resolveCollectionId(
      data['collectionName'] as String?,
      storageMode,
      collectionRemoteId: data['collectionRemoteId'] as String?,
    );

    return db.into(db.clips).insert(
          ClipsCompanion.insert(
            collectionId: Value(collectionId),
            title: (data['title'] as String?) ?? '제목 없음',
            filePath: '',
            durationMs: (data['durationMs'] as num?)?.toInt() ?? 0,
            storageBytes: Value((data['storageBytes'] as num?)?.toInt() ?? 0),
            ownerScope: Value(ownerScope),
            ownerKey: Value(ownerKey),
            storageMode: Value(storageMode),
          ),
        );
  }

  /// 콜렉션 없이 당겨온 클립은 폴더 화면에서 도달할 방법이 없으므로,
  /// 이름이 없으면 "미분류" 콜렉션으로 대신 묶습니다.
  static const _uncategorizedCollectionName = '미분류';

  Future<int> _resolveCollectionId(
    String? collectionName,
    String storageMode, {
    String? collectionRemoteId,
  }) async {
    if (collectionRemoteId != null && collectionRemoteId.isNotEmpty) {
      final byRemoteId = await db.collectionsDao.findByRemoteId(collectionRemoteId);
      if (byRemoteId != null) return byRemoteId.id;
    }
    final name = collectionName != null && collectionName.trim().isNotEmpty
        ? collectionName.trim()
        : _uncategorizedCollectionName;
    final collection = await db.collectionsDao.findOrCreate(
      name,
      storageMode,
      remoteId: collectionRemoteId,
    );
    return collection.id;
  }

  Future<Map<String, dynamic>?> _downloadJsonMap(String fileId) async {
    final content = await googleDriveStorageService.downloadFileContent(fileId);
    if (content == null) return null;
    try {
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String? _fileNameFromPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final segments = path.split('/');
    return segments.isEmpty ? null : segments.last;
  }

  Future<void> _insertSegments(int clipId, Object? rawSegments) async {
    if (rawSegments is! List) return;
    for (final raw in rawSegments) {
      if (raw is! Map) continue;
      await db.into(db.segments).insert(
            SegmentsCompanion.insert(
              clipId: clipId,
              startMs: (raw['startMs'] as num?)?.toInt() ?? 0,
              endMs: (raw['endMs'] as num?)?.toInt() ?? 0,
              original: (raw['original'] as String?) ?? '',
              pron: (raw['pron'] as String?) ?? '',
              trans: (raw['trans'] as String?) ?? '',
            ),
          );
    }
  }

  Future<void> _insertTags(int clipId, Object? rawTags) async {
    if (rawTags is! List) return;
    for (final raw in rawTags) {
      if (raw is! String || raw.isEmpty) continue;
      final tagId = await _ensureTag(raw);
      await db.into(db.clipTags).insert(
            ClipTagsCompanion.insert(clipId: clipId, tagId: tagId),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<int> _ensureTag(String name) async {
    final found =
        await (db.select(db.tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (found != null) return found.id;
    return db.into(db.tags).insert(TagsCompanion.insert(name: name));
  }
}
