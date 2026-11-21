// ============================================================================
// lib/core/collection_media/data/datasources/clip_file_sync_datasource.dart
// ============================================================================
//
// [역할]
// 재생 가능한 로컬 파일 확보(다운로드/캐시), 업로드용 소스 경로 확보,
// 원격 클립의 로컬 캐시 삭제를 전담하는 datasource.
//
// [레이어]
// Core > Collection Media > Data > Datasources
// ============================================================================

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:parrokit/core/infrastructure/services/cloud/user_file_storage.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/domain/collection_clip/data/utils/clip_path_utils.dart';
import 'clip_source_ref_datasource.dart';

class ClipFileSyncDatasource {
  final AppDatabase db;
  final ClipSourceRefDatasource sourceRefDatasource;
  final GoogleDriveStorageService googleDriveStorageService;

  ClipFileSyncDatasource(
    this.db,
    this.sourceRefDatasource,
    this.googleDriveStorageService,
  );

  Future<String> ensurePlayableClipFile(Clip clip) async {
    if (clip.storageMode == ClipStorageConstants.storageModeLocal) {
      final sourcePath = clip.sourceFilePath ?? clip.filePath;
      final absPath = await ClipPathUtils.absolutePathFor(sourcePath);
      final file = File(absPath);
      if (await file.exists() && await file.length() > 0) {
        return absPath;
      }
      throw StateError('로컬 파일을 찾을 수 없습니다.');
    }

    final sourceRef =
        await sourceRefDatasource.requireCurrentClipSourceRef(clip);
    final cacheEntry =
        await sourceRefDatasource.getClipCacheEntryForSourceRef(sourceRef);
    if (cacheEntry != null) {
      final absPath = await ClipPathUtils.absolutePathFor(cacheEntry.filePath);
      final file = File(absPath);
      if (await file.exists() && await file.length() > 0) {
        return absPath;
      }
    }

    final relativePath = await ClipPathUtils.defaultCachePathForClip(
      clipId: clip.id,
      remoteDocId: sourceRef.remoteDocId,
      extensionHint: sourceRef.provider ==
              ClipStorageConstants.providerGoogleDrive
          ? p.extension(sourceRef.storagePath ?? sourceRef.remoteFileId ?? '')
          : p.extension(sourceRef.storagePath ?? ''),
    );
    final absPath = await ClipPathUtils.absolutePathFor(relativePath);
    final destination = File(absPath);

    if (sourceRef.provider == ClipStorageConstants.providerServer) {
      await _restoreServerClipFile(sourceRef, destination);
    } else if (sourceRef.provider == ClipStorageConstants.providerGoogleDrive) {
      await _restoreCloudClipFile(sourceRef, destination);
    } else {
      throw StateError('원격 저장 방식이 올바르지 않습니다.');
    }

    await sourceRefDatasource.upsertClipCacheEntry(
      clipId: clip.id,
      provider: sourceRef.provider,
      ownerScope: sourceRef.ownerScope,
      ownerKey: sourceRef.ownerKey,
      filePath: relativePath,
      storageBytes: clip.storageBytes,
    );
    return absPath;
  }

  Future<String> resolveUploadSourcePath(Clip clip) async {
    if (clip.storageMode == ClipStorageConstants.storageModeLocal) {
      final sourcePath = clip.sourceFilePath ?? clip.filePath;
      final absPath = await ClipPathUtils.absolutePathFor(sourcePath);
      final file = File(absPath);
      if (!await file.exists()) {
        throw StateError('로컬 원본 파일을 찾을 수 없습니다.');
      }
      return sourcePath;
    }

    final cacheEntry = await sourceRefDatasource.getCurrentClipCacheEntry(clip);
    if (cacheEntry != null) {
      final absPath = await ClipPathUtils.absolutePathFor(cacheEntry.filePath);
      final file = File(absPath);
      if (await file.exists() && await file.length() > 0) {
        return cacheEntry.filePath;
      }
    }

    await ensurePlayableClipFile(clip);
    final refreshed = await sourceRefDatasource.getCurrentClipCacheEntry(clip);
    if (refreshed == null) {
      throw StateError('업로드할 재생 캐시를 준비하지 못했습니다.');
    }
    return refreshed.filePath;
  }

  Future<String> ensureLocalSourcePath({
    required Clip target,
    required ClipSourceRef sourceRef,
  }) async {
    final existingSource = target.sourceFilePath;
    if (existingSource != null && existingSource.isNotEmpty) {
      final absPath = await ClipPathUtils.absolutePathFor(existingSource);
      final file = File(absPath);
      if (await file.exists() && await file.length() > 0) {
        return existingSource;
      }
    }

    final cacheEntry =
        await sourceRefDatasource.getClipCacheEntryForSourceRef(sourceRef);
    if (cacheEntry != null) {
      final absPath = await ClipPathUtils.absolutePathFor(cacheEntry.filePath);
      final file = File(absPath);
      if (await file.exists() && await file.length() > 0) {
        return cacheEntry.filePath;
      }
    }

    final sourcePath = await ClipPathUtils.defaultSourcePathForClip(
      clipId: target.id,
      title: target.title,
      remoteDocId: sourceRef.remoteDocId,
      extensionHint: p.extension(
        sourceRef.storagePath ??
            sourceRef.remoteFileId ??
            sourceRef.downloadUrl ??
            '',
      ),
    );
    final absPath = await ClipPathUtils.absolutePathFor(sourcePath);
    final destination = File(absPath);
    if (sourceRef.provider == ClipStorageConstants.providerServer) {
      await _restoreServerClipFile(sourceRef, destination);
    } else {
      await _restoreCloudClipFile(sourceRef, destination);
    }
    return sourcePath;
  }

  Future<bool> clearRemoteClipCache(int clipId) async {
    final clip = await (db.select(db.clips)
          ..where((c) => c.id.equals(clipId))
          ..limit(1))
        .getSingleOrNull();
    if (clip == null) {
      throw StateError('클립을 찾을 수 없습니다.');
    }
    if (clip.storageMode == ClipStorageConstants.storageModeLocal) {
      throw StateError('로컬 저장본은 캐시로 지울 수 없습니다.');
    }

    final cacheEntry = await sourceRefDatasource.getCurrentClipCacheEntry(clip);
    if (cacheEntry == null) {
      return true;
    }

    final absPath = await ClipPathUtils.absolutePathFor(cacheEntry.filePath);
    final file = File(absPath);
    if (await file.exists()) {
      await file.delete();
      AppLogger.i(
        '[Clip][Cache] clear-cache success clipId=$clipId path=$absPath',
      );
    } else {
      AppLogger.i(
        '[Clip][Cache] clear-cache skip-missing clipId=$clipId path=$absPath',
      );
    }
    await (db.delete(db.clipCacheEntries)
          ..where(
            (c) =>
                c.clipId.equals(clipId) &
                c.provider.equals(cacheEntry.provider) &
                c.ownerScope.equals(cacheEntry.ownerScope) &
                c.ownerKey.equals(cacheEntry.ownerKey),
          ))
        .go();
    return true;
  }

  /// [ownerScope]+[ownerKey]로 스코프된 원격 클립의 로컬 캐시 파일과
  /// [ClipCacheEntries] 로우를 전부 정리합니다. 계정 로그아웃, Google Drive
  /// 연동 해제 시 해당 계정 소유 캐시만 지우는 용도입니다.
  Future<void> clearCacheForOwner({
    required String ownerScope,
    required String ownerKey,
  }) async {
    final entries = await (db.select(db.clipCacheEntries)
          ..where(
            (c) =>
                c.ownerScope.equals(ownerScope) & c.ownerKey.equals(ownerKey),
          ))
        .get();
    if (entries.isEmpty) return;

    for (final entry in entries) {
      final absPath = await ClipPathUtils.absolutePathFor(entry.filePath);
      final file = File(absPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await (db.delete(db.clipCacheEntries)
          ..where(
            (c) =>
                c.ownerScope.equals(ownerScope) & c.ownerKey.equals(ownerKey),
          ))
        .go();

    AppLogger.i(
      '[Clip][Cache] clear-cache-for-owner success ownerScope=$ownerScope count=${entries.length}',
    );
  }

  Future<void> _restoreServerClipFile(
    ClipSourceRef sourceRef,
    File destination,
  ) async {
    final hasPath =
        sourceRef.storagePath != null && sourceRef.storagePath!.isNotEmpty;
    final hasUrl =
        sourceRef.downloadUrl != null && sourceRef.downloadUrl!.isNotEmpty;
    if (!hasPath && !hasUrl) {
      throw StateError('서버 파일 경로를 찾을 수 없습니다.');
    }

    await UserFileStorage.instance.downloadToFile(
      path: hasPath ? sourceRef.storagePath : null,
      url: hasUrl ? sourceRef.downloadUrl : null,
      destination: destination,
    );
  }

  Future<void> _restoreCloudClipFile(
    ClipSourceRef sourceRef,
    File destination,
  ) async {
    final remoteFileId = sourceRef.remoteFileId;
    if (remoteFileId == null || remoteFileId.isEmpty) {
      throw StateError('클라우드 원본 정보를 찾을 수 없습니다.');
    }

    await destination.parent.create(recursive: true);
    await googleDriveStorageService.downloadClipFile(
      fileId: remoteFileId,
      destination: destination,
    );
  }
}
