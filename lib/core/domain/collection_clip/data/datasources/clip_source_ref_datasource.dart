// ============================================================================
// lib/core/collection_media/data/datasources/clip_source_ref_datasource.dart
// ============================================================================
//
// [역할]
// clip_source_refs / clip_cache_entries 테이블 접근과 provider·ownerScope
// 판별, 그리고 클립 가시성(현재 로그인 계정/gdrive 계정 기준) 필터링을
// 전담하는 datasource. "이 클립이 지금 보이는지", "이 클립의 현재 계정
// 기준 원격 원본이 무엇인지" 질의를 이 클래스 하나로만 처리해서, 다른
// 곳에서 같은 로직을 복제하다가 생기는 불일치(예: gdrive 클립인데
// app_account로 조회하는 버그)를 막습니다.
//
// [레이어]
// Core > Collection Media > Data > Datasources
// ============================================================================

import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:parrokit/core/infrastructure/services/cloud/user_file_storage.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'cached_files_on_disk.dart';

class ClipSourceRefDatasource {
  final AppDatabase db;
  final GoogleDriveStorageService googleDriveStorageService;

  ClipSourceRefDatasource(this.db, this.googleDriveStorageService);

  String? get _currentAccountId => fb.FirebaseAuth.instance.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────
  // Clip visibility (현재 로그인 계정/gdrive 계정 기준 가시성 필터)
  // ─────────────────────────────────────────────────────────────────

  Future<bool> isClipVisible(Clip clip) async {
    if (clip.ownerScope == ClipStorageConstants.ownerScopeDevice) return true;
    if (clip.ownerScope == ClipStorageConstants.ownerScopeAppAccount) {
      final accountId = _currentAccountId;
      return accountId != null && clip.ownerKey == accountId;
    }
    if (clip.ownerScope == ClipStorageConstants.ownerScopeCloudAccount) {
      final accountKey = await googleDriveStorageService.currentAccountKey();
      return accountKey != null && clip.ownerKey == accountKey;
    }
    return false;
  }

  /// 클립 하나하나마다 [isClipVisible]을 호출하면 gdrive 계정 조회
  /// (`signInSilently`)가 클립 수만큼 반복 실행되어 클립이 많을 때 눈에
  /// 띄게 느려집니다. 계정 정보를 한 번만 조회해 재사용합니다.
  Future<List<Clip>> visibleClips() async {
    final rows = await db.select(db.clips).get();
    final appAccountId = _currentAccountId;
    final googleAccountKey =
        await googleDriveStorageService.currentAccountKey();

    return rows.where((clip) {
      if (clip.ownerScope == ClipStorageConstants.ownerScopeDevice) {
        return true;
      }
      if (clip.ownerScope == ClipStorageConstants.ownerScopeAppAccount) {
        return appAccountId != null && clip.ownerKey == appAccountId;
      }
      if (clip.ownerScope == ClipStorageConstants.ownerScopeCloudAccount) {
        return googleAccountKey != null && clip.ownerKey == googleAccountKey;
      }
      return false;
    }).toList();
  }

  Future<List<Clip>> visibleClipsByStorageMode(String storageMode) async {
    final clips = await visibleClips();
    return clips.where((clip) => clip.storageMode == storageMode).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<List<Clip>> visibleRemoteClips() async {
    final clips = await visibleClips();
    return clips
        .where(
            (clip) => clip.storageMode != ClipStorageConstants.storageModeLocal)
        .toList();
  }

  String providerForStorageMode(String storageMode) {
    return switch (storageMode) {
      ClipStorageConstants.storageModeServer =>
        ClipStorageConstants.providerServer,
      ClipStorageConstants.storageModeGoogleDrive =>
        ClipStorageConstants.providerGoogleDrive,
      _ => throw StateError('원격 저장 방식이 올바르지 않습니다.'),
    };
  }

  String ownerScopeForProvider(String provider) {
    return switch (provider) {
      ClipStorageConstants.providerServer =>
        ClipStorageConstants.ownerScopeAppAccount,
      ClipStorageConstants.providerGoogleDrive =>
        ClipStorageConstants.ownerScopeCloudAccount,
      _ => throw StateError('원격 저장 제공자가 올바르지 않습니다.'),
    };
  }

  Future<String?> currentOwnerKeyForProvider(String provider) async {
    return switch (provider) {
      ClipStorageConstants.providerServer => _currentAccountId,
      ClipStorageConstants.providerGoogleDrive =>
        googleDriveStorageService.currentAccountKey(),
      _ => null,
    };
  }

  Future<ClipSourceRef?> getClipSourceRef({
    required int clipId,
    required String provider,
    required String ownerScope,
    required String ownerKey,
  }) {
    return (db.select(db.clipSourceRefs)
          ..where(
            (c) =>
                c.clipId.equals(clipId) &
                c.provider.equals(provider) &
                c.ownerScope.equals(ownerScope) &
                c.ownerKey.equals(ownerKey),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<ClipSourceRef> requireCurrentClipSourceRef(Clip clip) async {
    final ref = await getCurrentClipSourceRef(clip);
    if (ref == null) {
      throw StateError('현재 소유자의 원격 원본 정보를 찾을 수 없습니다.');
    }
    return ref;
  }

  Future<ClipSourceRef?> getCurrentClipSourceRef(Clip clip) async {
    if (clip.storageMode == ClipStorageConstants.storageModeLocal) return null;
    final provider = providerForStorageMode(clip.storageMode);
    final ownerScope = ownerScopeForProvider(provider);
    final ownerKey = await currentOwnerKeyForProvider(provider);
    if (ownerKey == null || ownerKey.isEmpty) return null;
    return getClipSourceRef(
      clipId: clip.id,
      provider: provider,
      ownerScope: ownerScope,
      ownerKey: ownerKey,
    );
  }

  Future<ClipCacheEntry?> getCurrentClipCacheEntry(Clip clip) async {
    final sourceRef = await getCurrentClipSourceRef(clip);
    if (sourceRef == null) return null;
    return getClipCacheEntryForSourceRef(sourceRef);
  }

  Future<ClipCacheEntry?> getClipCacheEntryForSourceRef(
    ClipSourceRef sourceRef,
  ) {
    return getClipCacheEntry(
      clipId: sourceRef.clipId,
      provider: sourceRef.provider,
      ownerScope: sourceRef.ownerScope,
      ownerKey: sourceRef.ownerKey,
    );
  }

  Future<ClipCacheEntry?> getClipCacheEntry({
    required int clipId,
    required String provider,
    required String ownerScope,
    required String ownerKey,
  }) async {
    return (db.select(db.clipCacheEntries)
          ..where(
            (c) =>
                c.clipId.equals(clipId) &
                c.provider.equals(provider) &
                c.ownerScope.equals(ownerScope) &
                c.ownerKey.equals(ownerKey),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertClipSourceRef({
    required int clipId,
    required String provider,
    required String ownerScope,
    required String ownerKey,
    required String remoteDocId,
    String? storagePath,
    String? downloadUrl,
    String? thumbnailStoragePath,
    String? thumbnailDownloadUrl,
    String? thumbnailRemoteFileId,
    String? remoteFileId,
    String? cloudFolderId,
    String? metadataPath,
    required DateTime lastSyncedAt,
  }) async {
    await db.into(db.clipSourceRefs).insertOnConflictUpdate(
          ClipSourceRefsCompanion.insert(
            clipId: clipId,
            provider: provider,
            ownerScope: ownerScope,
            ownerKey: ownerKey,
            remoteDocId: remoteDocId,
            storagePath: Value(storagePath),
            downloadUrl: Value(downloadUrl),
            thumbnailStoragePath: Value(thumbnailStoragePath),
            thumbnailDownloadUrl: Value(thumbnailDownloadUrl),
            thumbnailRemoteFileId: Value(thumbnailRemoteFileId),
            remoteFileId: Value(remoteFileId),
            cloudFolderId: Value(cloudFolderId),
            metadataPath: Value(metadataPath),
            lastSyncedAt: Value(lastSyncedAt),
          ),
        );
  }

  Future<void> upsertClipCacheEntry({
    required int clipId,
    required String provider,
    required String ownerScope,
    required String ownerKey,
    required String filePath,
    required int storageBytes,
  }) async {
    await db.into(db.clipCacheEntries).insertOnConflictUpdate(
          ClipCacheEntriesCompanion.insert(
            clipId: clipId,
            provider: provider,
            ownerScope: ownerScope,
            ownerKey: ownerKey,
            filePath: filePath,
            storageBytes: Value(storageBytes),
            cachedAt: Value(DateTime.now()),
            lastAccessedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> retainOnlyCurrentRemoteRows({
    required int clipId,
    required String provider,
    required String ownerScope,
    required String ownerKey,
  }) async {
    await (db.delete(db.clipSourceRefs)
          ..where(
            (c) =>
                c.clipId.equals(clipId) &
                (c.provider.equals(provider) &
                        c.ownerScope.equals(ownerScope) &
                        c.ownerKey.equals(ownerKey))
                    .not(),
          ))
        .go();
    await (db.delete(db.clipCacheEntries)
          ..where(
            (c) =>
                c.clipId.equals(clipId) &
                (c.provider.equals(provider) &
                        c.ownerScope.equals(ownerScope) &
                        c.ownerKey.equals(ownerKey))
                    .not(),
          ))
        .go();
  }

  Future<void> deleteAllRemoteRowsForClip(int clipId) async {
    await (db.delete(db.clipSourceRefs)..where((c) => c.clipId.equals(clipId)))
        .go();
    await (db.delete(db.clipCacheEntries)
          ..where((c) => c.clipId.equals(clipId)))
        .go();
  }

  /// 현재 계정 소유이면서, 실제로 살아있는(=visibleRemoteClips에 존재하는)
  /// 클립에 연결된 캐시 로우만 반환합니다. 클립 삭제/이관 과정에서 미처
  /// 정리되지 못한 고아 캐시 로우가 저장공간 사용량 표시를 실제 캐시
  /// 목록과 다르게 부풀리는 것을 막기 위한 필터입니다.
  Future<List<ClipCacheEntry>> currentCacheEntries() async {
    final entries = await db.select(db.clipCacheEntries).get();
    final appAccountId = _currentAccountId;
    final googleAccountKey =
        await googleDriveStorageService.currentAccountKey();

    final ownerMatched = entries.where((entry) {
      if (entry.ownerScope == ClipStorageConstants.ownerScopeAppAccount) {
        return appAccountId != null && entry.ownerKey == appAccountId;
      }
      if (entry.ownerScope == ClipStorageConstants.ownerScopeCloudAccount) {
        return googleAccountKey != null && entry.ownerKey == googleAccountKey;
      }
      return false;
    }).toList();
    if (ownerMatched.isEmpty) return ownerMatched;

    final liveClipIds =
        (await visibleRemoteClips()).map((clip) => clip.id).toSet();
    final live = ownerMatched
        .where((entry) => liveClipIds.contains(entry.clipId))
        .toList();
    // 파일이 사라진 줄은 세지 않는다(5차 363). '받아 둔 영상' 목록이 쓰는
    // 규칙과 같아야 더보기의 개수·용량이 목록과 어긋나지 않는다.
    return keepFilesStillOnDisk(live, filePathOf: (entry) => entry.filePath);
  }

  /// 서버(Firebase Storage)/Google Drive에 올라간 원본·썸네일 파일과 metadata.json을
  /// 삭제합니다. Firestore의 library 문서 자체는 호출자가 별도로 지웁니다.
  Future<void> deleteRemoteLinkSource(ClipSourceRef sourceRef) async {
    if (sourceRef.provider == ClipStorageConstants.providerServer) {
      await _deleteRemoteStorageObject(
        storagePath: sourceRef.storagePath,
        downloadUrl: sourceRef.downloadUrl,
      );
      await _deleteRemoteStorageObject(
        storagePath: sourceRef.thumbnailStoragePath,
        downloadUrl: sourceRef.thumbnailDownloadUrl,
      );
      return;
    }

    if (sourceRef.provider == ClipStorageConstants.providerGoogleDrive) {
      final folderId = sourceRef.cloudFolderId;
      if (folderId != null && folderId.isNotEmpty) {
        // 폴더를 통째로 지우면 그 안의 video/thumbnail/metadata.json이 한
        // 번의 호출로 함께 삭제된다. 이전에는 파일을 하나씩 따로 지웠는데,
        // 중간 호출 하나가 실패하면 metadata.json이 남은 빈 폴더가 Drive에
        // 남고, pull sync가 이를 별개의 클립으로 다시 주워와 중복이
        // 생기는 원인이 됐다.
        await googleDriveStorageService.deleteFile(folderId);
        return;
      }
      final remoteFileId = sourceRef.remoteFileId;
      if (remoteFileId != null && remoteFileId.isNotEmpty) {
        await googleDriveStorageService.deleteFile(remoteFileId);
      }
      final thumbnailRemoteFileId = sourceRef.thumbnailRemoteFileId;
      if (thumbnailRemoteFileId != null && thumbnailRemoteFileId.isNotEmpty) {
        await googleDriveStorageService.deleteFile(thumbnailRemoteFileId);
      }
    }
  }

  Future<void> _deleteRemoteStorageObject({
    String? storagePath,
    String? downloadUrl,
  }) async {
    // 실패는 서비스가 w로 남기고 false를 돌려준다. 흐름은 막지 않는다.
    await UserFileStorage.instance.deleteQuietly(
      path: storagePath,
      url: downloadUrl,
    );
  }
}
