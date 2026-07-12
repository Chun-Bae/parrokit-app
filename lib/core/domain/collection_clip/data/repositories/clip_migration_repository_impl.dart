// ============================================================================
// lib/core/collection_media/data/repositories/clip_migration_repository_impl.dart
// ============================================================================
//
// [역할]
// ClipMigrationRepository 구현체. moveClipToServer/GoogleDrive/Local과
// 저장 용량·Google Drive 계정 조회를 담당하며, 나머지 세부 로직(썸네일,
// 재생 파일 확보, 소스 참조 기록, Firestore/gdrive 메타데이터)은 각
// datasource에 위임하는 최상위 오케스트레이터입니다.
//
// [레이어]
// Core > Collection Media > Data > Repositories
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/domain/collection_clip/data/utils/clip_path_utils.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_source_ref_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_thumbnail_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_file_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/collection_group_mirror_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_remote_library_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_firestore_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_cloud_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_detail_query_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/remote_doc_id_resolver.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_sync_coordinator.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/clip_migration_repository.dart';

class ClipMigrationRepositoryImpl implements ClipMigrationRepository {
  final AppDatabase db;
  final ClipSourceRefDatasource sourceRefDatasource;
  final ClipThumbnailDatasource thumbnailDatasource;
  final ClipFileSyncDatasource fileSyncDatasource;
  final CollectionGroupMirrorDatasource collectionGroupMirrorDatasource;
  final ClipRemoteLibrarySyncDatasource remoteLibrarySyncDatasource;
  final ClipFirestoreMetadataDatasource firestoreMetadataDatasource;
  final ClipCloudMetadataDatasource cloudMetadataDatasource;
  final ClipDetailQueryDatasource detailQueryDatasource;
  final RemoteDocIdResolver remoteDocIdResolver;
  final GoogleDriveStorageService googleDriveStorageService;
  final LibraryEntitySyncCoordinator libraryEntitySyncCoordinator;

  ClipMigrationRepositoryImpl({
    required this.db,
    required this.sourceRefDatasource,
    required this.thumbnailDatasource,
    required this.fileSyncDatasource,
    required this.collectionGroupMirrorDatasource,
    required this.remoteLibrarySyncDatasource,
    required this.firestoreMetadataDatasource,
    required this.cloudMetadataDatasource,
    required this.detailQueryDatasource,
    required this.remoteDocIdResolver,
    required this.googleDriveStorageService,
    required this.libraryEntitySyncCoordinator,
  });

  @override
  Future<void> moveClipToServer(
    int clipId, {
    ClipMigrationProgressCallback? onProgress,
  }) async {
    AppLogger.i('[Clip][Storage] move-to-server start clipId=$clipId');

    final target = await (db.select(db.clips)
          ..where((c) => c.id.equals(clipId))
          ..limit(1))
        .getSingleOrNull();
    if (target == null) {
      throw StateError('클립을 찾을 수 없습니다.');
    }

    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('서버 저장하려면 로그인이 필요합니다.');
    }

    final previousStorageMode = target.storageMode;
    final previousSourceRef =
        await sourceRefDatasource.getCurrentClipSourceRef(target);
    if (previousStorageMode == ClipStorageConstants.storageModeServer &&
        previousSourceRef != null) {
      AppLogger.i(
        '[Clip][Storage] move-to-server skip already-server clipId=$clipId',
      );
      return;
    }

    final sourcePath = await fileSyncDatasource.resolveUploadSourcePath(target);
    final absPath = await ClipPathUtils.absolutePathFor(sourcePath);
    final file = File(absPath);
    if (!await file.exists()) {
      throw StateError('업로드할 파일을 찾을 수 없습니다.');
    }

    final remoteDocId =
        previousSourceRef?.remoteDocId ?? remoteDocIdResolver.newClipDocId();
    final extension = p.extension(absPath);
    final normalizedExtension = extension.isEmpty ? '.mp4' : extension;
    final contentType = lookupMimeType(absPath) ?? 'application/octet-stream';
    final fileSize = await file.length();
    onProgress?.call(0, fileSize, '영상 파일을 확인하고 있어요');
    final storagePath =
        'users/${user.uid}/clips/$remoteDocId/video$normalizedExtension';
    final thumbnailPath = await thumbnailDatasource.ensureThumbnailFile(
      clipId: clipId,
      videoPath: sourcePath,
      existingThumbnailPath: target.thumbnailFilePath,
      remoteDocId: remoteDocId,
    );
    final thumbnailFile = thumbnailPath == null
        ? null
        : File(await ClipPathUtils.absolutePathFor(thumbnailPath));
    final thumbnailStoragePath =
        'users/${user.uid}/clips/$remoteDocId/thumbnail.jpg';

    // 영상과 썸네일을 각각 0%부터 올리면 진행률이 두 번 리셋되는 것처럼
    // 보인다. 두 파일 크기를 합친 하나의 진행률로 통일한다.
    final hasThumbnail = thumbnailFile != null && await thumbnailFile.exists();
    final thumbnailFileSize = hasThumbnail ? await thumbnailFile.length() : 0;
    final combinedUploadTotal = fileSize + thumbnailFileSize;

    Future<({String storagePath, String downloadUrl})> uploadToPath(
      String storagePath, {
      required File uploadFile,
      required String uploadContentType,
      required int baseBytes,
    }) async {
      final storageRef = FirebaseStorage.instance.ref(storagePath);
      final metadata = SettableMetadata(contentType: uploadContentType);
      final uploadFileSize = await uploadFile.length();
      AppLogger.d(
        '[Clip][Storage] server-upload start clipId=$clipId path=$storagePath contentType=$uploadContentType bytes=$uploadFileSize',
      );

      Future<({String storagePath, String downloadUrl})> runTask(
        UploadTask uploadTask, {
        required bool isRetry,
      }) async {
        late final StreamSubscription<TaskSnapshot> subscription;
        try {
          subscription = uploadTask.snapshotEvents.listen((snapshot) {
            onProgress?.call(
              baseBytes + snapshot.bytesTransferred,
              combinedUploadTotal,
              isRetry
                  ? '서버에 업로드하고 있어요 (다시 시도하는 중)'
                  : '서버에 업로드하고 있어요',
            );
          });

          final taskSnapshot = await uploadTask;
          AppLogger.d(
            '[Clip][Storage] server-upload-finished clipId=$clipId path=$storagePath',
          );
          final downloadUrl = await taskSnapshot.ref.getDownloadURL();
          return (storagePath: storagePath, downloadUrl: downloadUrl);
        } finally {
          await subscription.cancel();
        }
      }

      try {
        return await runTask(
          storageRef.putFile(uploadFile, metadata),
          isRetry: false,
        );
      } on fb.FirebaseException catch (e, st) {
        AppLogger.w(
          '[Clip][Storage] server-upload putFile-failed clipId=$clipId path=$storagePath code=${e.code} message=${e.message}',
          error: e,
          stackTrace: st,
        );

        final bytes = await uploadFile.readAsBytes();
        AppLogger.d(
          '[Clip][Storage] server-upload fallback-putData clipId=$clipId path=$storagePath bytes=${bytes.length}',
        );
        return runTask(
          storageRef.putData(bytes, metadata),
          isRetry: true,
        );
      }
    }

    late final ({String storagePath, String downloadUrl}) uploadResult;
    ({String storagePath, String downloadUrl})? thumbnailUploadResult;
    try {
      uploadResult = await uploadToPath(
        storagePath,
        uploadFile: file,
        uploadContentType: contentType,
        baseBytes: 0,
      );
      if (hasThumbnail) {
        thumbnailUploadResult = await uploadToPath(
          thumbnailStoragePath,
          uploadFile: thumbnailFile,
          uploadContentType: 'image/jpeg',
          baseBytes: fileSize,
        );
      }

      final now = DateTime.now();
      final segments = await detailQueryDatasource.segmentsForClip(clipId);
      final tagNames = await detailQueryDatasource.tagNamesForClip(clipId);
      final collection = target.collectionId == null
          ? null
          : await (db.select(db.collections)
                ..where((c) => c.id.equals(target.collectionId!))
                ..limit(1))
              .getSingleOrNull();
      final groupNames =
          await cloudMetadataDatasource.groupNamesForCollection(target.collectionId);

      final docRef =
          firestoreMetadataDatasource.libraryClipDocRef(user.uid, remoteDocId);
      await firestoreMetadataDatasource.cleanupLegacyLibraryClipDocs(
        uid: user.uid,
        clipId: clipId,
        keepDocId: remoteDocId,
      );
      await docRef.set({
        'localId': target.id,
        'title': target.title,
        'storageMode': ClipStorageConstants.storageModeServer,
        'provider': ClipStorageConstants.providerServer,
        'ownerScope': ClipStorageConstants.ownerScopeAppAccount,
        'ownerKey': user.uid,
        'remoteDocId': remoteDocId,
        'storageBytes': fileSize,
        'durationMs': target.durationMs,
        'storagePath': uploadResult.storagePath,
        'downloadUrl': uploadResult.downloadUrl,
        'thumbnailStoragePath':
            thumbnailUploadResult?.storagePath ?? FieldValue.delete(),
        'thumbnailDownloadUrl':
            thumbnailUploadResult?.downloadUrl ?? FieldValue.delete(),
        // 다른 기기에서 pull sync로 받아올 때 콜렉션에 자동으로 넣어주기
        // 위한 최소 정보. collectionRemoteId가 있으면 정확히 매칭되고,
        // 없으면 collectionName으로 폴백한다.
        'collectionName': collection?.name ?? FieldValue.delete(),
        'collectionRemoteId': collection?.remoteId ?? FieldValue.delete(),
        // 참고용 정보일 뿐 pull sync에서 자동으로 적용하지 않는다 — 그룹은
        // 저장위치별로 독립된 개념이라 이동/당겨오기 시 그대로 따라가지
        // 않는다.
        'groupNames':
            groupNames.isNotEmpty ? groupNames : FieldValue.delete(),
        'segments': segments
            .map(
              (segment) => {
                'startMs': segment.startMs,
                'endMs': segment.endMs,
                'original': segment.original,
                'pron': segment.pron,
                'trans': segment.trans,
              },
            )
            .toList(),
        'tags': tagNames,
        'remoteFileId': FieldValue.delete(),
        'cloudFolderId': FieldValue.delete(),
        'storageProvider': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await sourceRefDatasource.upsertClipSourceRef(
        clipId: clipId,
        provider: ClipStorageConstants.providerServer,
        ownerScope: ClipStorageConstants.ownerScopeAppAccount,
        ownerKey: user.uid,
        remoteDocId: remoteDocId,
        storagePath: uploadResult.storagePath,
        downloadUrl: uploadResult.downloadUrl,
        thumbnailStoragePath: thumbnailUploadResult?.storagePath,
        thumbnailDownloadUrl: thumbnailUploadResult?.downloadUrl,
        lastSyncedAt: now,
      );
      await sourceRefDatasource.upsertClipCacheEntry(
        clipId: clipId,
        provider: ClipStorageConstants.providerServer,
        ownerScope: ClipStorageConstants.ownerScopeAppAccount,
        ownerKey: user.uid,
        filePath: sourcePath,
        storageBytes: fileSize,
      );

      final oldCollectionId = target.collectionId;
      final newCollectionId = await collectionGroupMirrorDatasource
          .mirrorCollectionForClip(
        currentCollectionId: oldCollectionId,
        destinationStorageMode: ClipStorageConstants.storageModeServer,
      );

      await (db.update(db.clips)..where((c) => c.id.equals(clipId))).write(
        ClipsCompanion(
          collectionId: Value(newCollectionId),
          filePath: const Value(''),
          sourceFilePath: const Value.absent(),
          ownerScope: const Value(ClipStorageConstants.ownerScopeAppAccount),
          ownerKey: Value(user.uid),
          storageMode: const Value(ClipStorageConstants.storageModeServer),
          storageBytes: Value(fileSize),
          thumbnailFilePath: Value(thumbnailPath),
        ),
      );
      if (oldCollectionId != null && oldCollectionId != newCollectionId) {
        await _pruneCollectionIfEmpty(oldCollectionId);
      }

      await _cleanupPreviousRemoteSource(
        clipId: clipId,
        previousStorageMode: previousStorageMode,
        previousSourceRef: previousSourceRef,
        currentProvider: ClipStorageConstants.providerServer,
        currentOwnerScope: ClipStorageConstants.ownerScopeAppAccount,
        currentOwnerKey: user.uid,
      );
      await sourceRefDatasource.retainOnlyCurrentRemoteRows(
        clipId: clipId,
        provider: ClipStorageConstants.providerServer,
        ownerScope: ClipStorageConstants.ownerScopeAppAccount,
        ownerKey: user.uid,
      );

      AppLogger.i(
        '[Clip][Storage] move-to-server success clipId=$clipId remoteId=$remoteDocId',
      );
    } on fb.FirebaseException catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] server-upload firebase-error clipId=$clipId code=${e.code} message=${e.message}',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } on Exception catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] server-upload error clipId=$clipId',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> moveClipToGoogleDrive(
    int clipId, {
    ClipMigrationProgressCallback? onProgress,
  }) async {
    AppLogger.i('[Clip][Storage] move-to-gdrive start clipId=$clipId');

    final target = await (db.select(db.clips)
          ..where((c) => c.id.equals(clipId))
          ..limit(1))
        .getSingleOrNull();
    if (target == null) {
      throw StateError('클립을 찾을 수 없습니다.');
    }

    final previousStorageMode = target.storageMode;
    final previousSourceRef =
        await sourceRefDatasource.getCurrentClipSourceRef(target);
    if (previousStorageMode == ClipStorageConstants.providerGoogleDrive &&
        previousSourceRef != null) {
      AppLogger.i(
        '[Clip][Storage] move-to-gdrive skip already-gdrive clipId=$clipId',
      );
      return;
    }

    final sourcePath = await fileSyncDatasource.resolveUploadSourcePath(target);
    final absPath = await ClipPathUtils.absolutePathFor(sourcePath);
    final file = File(absPath);
    if (!await file.exists()) {
      throw StateError('업로드할 파일을 찾을 수 없습니다.');
    }
    final fileSize = await file.length();

    final remoteDocId =
        previousSourceRef?.remoteDocId ?? remoteDocIdResolver.newClipDocId();
    final extension = p.extension(absPath);
    final normalizedExtension = extension.isEmpty ? '.mp4' : extension;
    onProgress?.call(0, 0, 'Google Drive 연결을 확인하고 있어요');
    final fileName = ClipPathUtils.buildDriveFileName(absPath);
    final cloudStoragePath = 'clips/$remoteDocId/video$normalizedExtension';
    final thumbnailPath = await thumbnailDatasource.ensureThumbnailFile(
      clipId: clipId,
      videoPath: sourcePath,
      existingThumbnailPath: target.thumbnailFilePath,
      remoteDocId: remoteDocId,
    );
    final thumbnailFile = thumbnailPath == null
        ? null
        : File(await ClipPathUtils.absolutePathFor(thumbnailPath));
    final thumbnailStoragePath = 'clips/$remoteDocId/thumbnail.jpg';
    final metadataPath = 'clips/$remoteDocId/metadata.json';

    // 영상과 썸네일을 각각 0%부터 올리면 진행률이 두 번 리셋되는 것처럼
    // 보인다. 두 파일 크기를 합친 하나의 진행률로 통일한다. 내부 서비스가
    // 완료 시 보내는 (1, 1) 같은 가짜 총량 신호는 걸러낸다.
    final hasThumbnail = thumbnailFile != null && await thumbnailFile.exists();
    final thumbnailFileSize = hasThumbnail ? await thumbnailFile.length() : 0;
    final combinedUploadTotal = fileSize + thumbnailFileSize;

    final result = await googleDriveStorageService.uploadClipFile(
      file: file,
      fileName: fileName,
      clipId: target.id.toString(),
      storagePath: cloudStoragePath,
      title: target.title,
      storageBytes: fileSize,
      durationMs: target.durationMs,
      remoteDocId: remoteDocId,
      ownerScope: ClipStorageConstants.ownerScopeCloudAccount,
      onProgress: (current, total, message) {
        if (total <= 1) return;
        onProgress?.call(current, combinedUploadTotal, message);
      },
    );
    GoogleDriveUploadResult? thumbnailResult;
    if (hasThumbnail) {
      thumbnailResult = await googleDriveStorageService.uploadClipFile(
        file: thumbnailFile,
        fileName: 'thumbnail.jpg',
        clipId: target.id.toString(),
        storagePath: thumbnailStoragePath,
        title: target.title,
        storageBytes: thumbnailFileSize,
        durationMs: target.durationMs,
        remoteDocId: remoteDocId,
        ownerScope: ClipStorageConstants.ownerScopeCloudAccount,
        onProgress: (current, total, message) {
          if (total <= 1) return;
          onProgress?.call(fileSize + current, combinedUploadTotal, message);
        },
      );
    }

    onProgress?.call(
      combinedUploadTotal,
      combinedUploadTotal,
      '저장 정보를 정리하고 있어요',
    );
    final metadata = await cloudMetadataDatasource.buildCloudClipMetadata(
      clip: target,
      remoteDocId: remoteDocId,
      ownerKey: result.accountKey,
      storagePath: cloudStoragePath,
      thumbnailStoragePath:
          thumbnailResult == null ? null : thumbnailStoragePath,
      storageBytes: fileSize,
    );
    await googleDriveStorageService.upsertJsonFile(
      storagePath: metadataPath,
      content: metadata,
      appProperties: {
        'clipId': target.id.toString(),
        'remoteDocId': remoteDocId,
        'storageMode': ClipStorageConstants.providerGoogleDrive,
        'provider': ClipStorageConstants.providerGoogleDrive,
        'ownerScope': ClipStorageConstants.ownerScopeCloudAccount,
        'ownerKey': result.accountKey,
        'metadataPath': metadataPath,
      },
    );

    final now = DateTime.now();
    await sourceRefDatasource.upsertClipSourceRef(
      clipId: clipId,
      provider: ClipStorageConstants.providerGoogleDrive,
      ownerScope: ClipStorageConstants.ownerScopeCloudAccount,
      ownerKey: result.accountKey,
      remoteDocId: remoteDocId,
      storagePath: cloudStoragePath,
      downloadUrl: result.webContentLink ?? result.webViewLink,
      remoteFileId: result.fileId,
      thumbnailStoragePath:
          thumbnailResult == null ? null : thumbnailStoragePath,
      thumbnailDownloadUrl:
          thumbnailResult?.webContentLink ?? thumbnailResult?.webViewLink,
      thumbnailRemoteFileId: thumbnailResult?.fileId,
      cloudFolderId: result.folderId,
      metadataPath: metadataPath,
      lastSyncedAt: now,
    );
    await sourceRefDatasource.upsertClipCacheEntry(
      clipId: clipId,
      provider: ClipStorageConstants.providerGoogleDrive,
      ownerScope: ClipStorageConstants.ownerScopeCloudAccount,
      ownerKey: result.accountKey,
      filePath: sourcePath,
      storageBytes: fileSize,
    );
    final oldCollectionId = target.collectionId;
    final newCollectionId =
        await collectionGroupMirrorDatasource.mirrorCollectionForClip(
      currentCollectionId: oldCollectionId,
      destinationStorageMode: ClipStorageConstants.storageModeGoogleDrive,
    );

    await (db.update(db.clips)..where((c) => c.id.equals(clipId))).write(
      ClipsCompanion(
        collectionId: Value(newCollectionId),
        filePath: const Value(''),
        sourceFilePath: const Value.absent(),
        ownerScope: const Value(ClipStorageConstants.ownerScopeCloudAccount),
        ownerKey: Value(result.accountKey),
        storageMode: const Value(ClipStorageConstants.providerGoogleDrive),
        storageBytes: Value(fileSize),
        thumbnailFilePath: Value(thumbnailPath),
      ),
    );
    if (oldCollectionId != null && oldCollectionId != newCollectionId) {
      await _pruneCollectionIfEmpty(oldCollectionId);
    }

    await _cleanupPreviousRemoteSource(
      clipId: clipId,
      previousStorageMode: previousStorageMode,
      previousSourceRef: previousSourceRef,
      currentProvider: ClipStorageConstants.providerGoogleDrive,
      currentOwnerScope: ClipStorageConstants.ownerScopeCloudAccount,
      currentOwnerKey: result.accountKey,
    );
    await sourceRefDatasource.retainOnlyCurrentRemoteRows(
      clipId: clipId,
      provider: ClipStorageConstants.providerGoogleDrive,
      ownerScope: ClipStorageConstants.ownerScopeCloudAccount,
      ownerKey: result.accountKey,
    );

    AppLogger.i(
      '[Clip][Storage] move-to-gdrive success clipId=$clipId remoteId=${result.fileId}',
    );
  }

  @override
  Future<void> moveClipToLocal(
    int clipId, {
    ClipMigrationProgressCallback? onProgress,
  }) async {
    AppLogger.i('[Clip][Storage] move-to-local start clipId=$clipId');

    final target = await (db.select(db.clips)
          ..where((c) => c.id.equals(clipId))
          ..limit(1))
        .getSingleOrNull();
    if (target == null) {
      throw StateError('클립을 찾을 수 없습니다.');
    }
    if (target.storageMode == ClipStorageConstants.storageModeLocal) {
      AppLogger.i(
        '[Clip][Storage] move-to-local skip already-local clipId=$clipId',
      );
      return;
    }

    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('로컬 전환을 위해 로그인 정보가 필요합니다.');
    }

    final sourceRef = await sourceRefDatasource.getCurrentClipSourceRef(target);
    if (sourceRef == null) {
      throw StateError('현재 계정의 원격 원본 정보를 찾을 수 없습니다.');
    }

    onProgress?.call(0, 0, '원본 영상을 내려받고 있어요');
    final sourcePath = await fileSyncDatasource.ensureLocalSourcePath(
      target: target,
      sourceRef: sourceRef,
    );
    onProgress?.call(0, 0, '내 기기에 정리하고 있어요');
    final thumbnailPath = await thumbnailDatasource.ensureThumbnailFile(
      clipId: clipId,
      videoPath: sourcePath,
      existingThumbnailPath: target.thumbnailFilePath,
      remoteDocId: sourceRef.remoteDocId,
    );

    await sourceRefDatasource.deleteRemoteLinkSource(sourceRef);
    if (sourceRef.provider == ClipStorageConstants.providerServer &&
        sourceRef.ownerScope == ClipStorageConstants.ownerScopeAppAccount) {
      await firestoreMetadataDatasource.deleteLibraryClipDoc(
        sourceRef.ownerKey,
        sourceRef.remoteDocId,
      );
    }

    final oldCollectionId = target.collectionId;
    final newCollectionId =
        await collectionGroupMirrorDatasource.mirrorCollectionForClip(
      currentCollectionId: oldCollectionId,
      destinationStorageMode: ClipStorageConstants.storageModeLocal,
    );

    await db.transaction(() async {
      await sourceRefDatasource.deleteAllRemoteRowsForClip(clipId);
      await (db.update(db.clips)..where((c) => c.id.equals(clipId))).write(
        ClipsCompanion(
          collectionId: Value(newCollectionId),
          filePath: Value(sourcePath),
          sourceFilePath: Value(sourcePath),
          ownerScope: const Value(ClipStorageConstants.ownerScopeDevice),
          ownerKey: const Value.absent(),
          storageMode: const Value(ClipStorageConstants.storageModeLocal),
          storageBytes: Value(await ClipPathUtils.fileSizeFor(sourcePath)),
          thumbnailFilePath: Value(thumbnailPath),
        ),
      );
    });
    if (oldCollectionId != null && oldCollectionId != newCollectionId) {
      await _pruneCollectionIfEmpty(oldCollectionId);
    }

    AppLogger.i(
      '[Clip][Storage] move-to-local success clipId=$clipId remoteId=${sourceRef.remoteDocId}',
    );
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
  Future<bool> clearRemoteClipCache(int clipId) {
    return fileSyncDatasource.clearRemoteClipCache(clipId);
  }

  @override
  Future<void> clearCachedFilesForCurrentAccount() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await fileSyncDatasource.clearCacheForOwner(
      ownerScope: ClipStorageConstants.ownerScopeAppAccount,
      ownerKey: user.uid,
    );
  }

  @override
  Future<int> pullServerClipsForCurrentAccount() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    return remoteLibrarySyncDatasource.pullServerClips(user.uid);
  }

  @override
  Future<int> pullCloudClipsForCurrentAccount() async {
    final accountKey = await googleDriveStorageService.currentAccountKey();
    if (accountKey == null) return 0;
    return remoteLibrarySyncDatasource.pullCloudClips(accountKey);
  }

  @override
  Future<int> pullServerLibraryStructureForCurrentAccount() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    return libraryEntitySyncCoordinator.pullServer(user.uid);
  }

  @override
  Future<int> pullCloudLibraryStructureForCurrentAccount() async {
    final accountKey = await googleDriveStorageService.currentAccountKey();
    if (accountKey == null) return 0;
    return libraryEntitySyncCoordinator.pullCloud();
  }

  @override
  Future<int> reconcileServerLibraryStructureForCurrentAccount() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    return libraryEntitySyncCoordinator.reconcileServerAfterClips(user.uid);
  }

  @override
  Future<int> reconcileCloudLibraryStructureForCurrentAccount() async {
    final accountKey = await googleDriveStorageService.currentAccountKey();
    if (accountKey == null) return 0;
    return libraryEntitySyncCoordinator.reconcileCloudAfterClips();
  }

  @override
  Future<int> getServerStorageUsedBytes() async {
    final rows = await sourceRefDatasource
        .visibleClipsByStorageMode(ClipStorageConstants.storageModeServer);
    return rows.fold<int>(
        0, (totalBytes, clip) => totalBytes + clip.storageBytes);
  }

  @override
  Future<int> getLocalStorageUsedBytes() async {
    final rows = await (db.select(db.clips)
          ..where((c) => c.storageMode.equals(ClipStorageConstants.storageModeLocal)))
        .get();
    return rows.fold<int>(
        0, (totalBytes, clip) => totalBytes + clip.storageBytes);
  }

  @override
  Future<int> getCloudStorageUsedBytes() async {
    final rows = await sourceRefDatasource.visibleRemoteClips().then(
          (clips) => clips
              .where((clip) =>
                  clip.storageMode == ClipStorageConstants.storageModeGoogleDrive)
              .toList(),
        );
    return rows.fold<int>(
        0, (totalBytes, clip) => totalBytes + clip.storageBytes);
  }

  @override
  Future<bool> hasGoogleDriveLinked() async {
    return googleDriveStorageService.hasConnectedAccount();
  }

  @override
  Future<void> connectGoogleDrive() async {
    final account = await googleDriveStorageService.connect();
    if (account == null) {
      throw StateError('Google Drive 연동이 취소되었습니다.');
    }
  }

  Future<int> _moveAllGoogleDriveClipsToLocal({
    void Function(int current, int total, String message)? onProgress,
  }) async {
    final clips = await sourceRefDatasource
        .visibleClipsByStorageMode(ClipStorageConstants.storageModeGoogleDrive);

    if (clips.isEmpty) {
      onProgress?.call(0, 0, '이동할 Google Drive 파일이 없습니다.');
      return 0;
    }

    var current = 0;
    for (final clip in clips) {
      onProgress?.call(
        current,
        clips.length,
        'Google Drive 파일을 로컬로 옮기는 중',
      );
      await moveClipToLocal(clip.id);
      current++;
      onProgress?.call(
        current,
        clips.length,
        'Google Drive 파일을 로컬로 옮기는 중',
      );
    }

    return current;
  }

  @override
  Future<void> disconnectGoogleDriveAfterLocalMove({
    void Function(int current, int total, String message)? onProgress,
  }) async {
    await _moveAllGoogleDriveClipsToLocal(onProgress: onProgress);
    final accountKey = await googleDriveStorageService.currentAccountKey();
    if (accountKey != null) {
      await fileSyncDatasource.clearCacheForOwner(
        ownerScope: ClipStorageConstants.ownerScopeCloudAccount,
        ownerKey: accountKey,
      );
    }
    await googleDriveStorageService.disconnect();
  }

  @override
  Future<int> getCachedRemoteStorageUsedBytes() async {
    final entries = await sourceRefDatasource.currentCacheEntries();
    return entries.fold<int>(
      0,
      (totalBytes, entry) => totalBytes + entry.storageBytes,
    );
  }

  @override
  Future<int> getCachedRemoteClipCount() async {
    final entries = await sourceRefDatasource.currentCacheEntries();
    return entries.length;
  }

  @override
  Future<GoogleDriveStorageQuota?> getGoogleDriveStorageQuota() async {
    return googleDriveStorageService.fetchStorageQuota();
  }

  Future<void> _cleanupPreviousRemoteSource({
    required int clipId,
    required String previousStorageMode,
    required ClipSourceRef? previousSourceRef,
    required String currentProvider,
    required String currentOwnerScope,
    required String currentOwnerKey,
  }) async {
    if (previousSourceRef == null) {
      return;
    }

    if (previousStorageMode == ClipStorageConstants.storageModeLocal) {
      return;
    }

    if (previousSourceRef.provider == currentProvider &&
        previousSourceRef.ownerScope == currentOwnerScope &&
        previousSourceRef.ownerKey == currentOwnerKey) {
      return;
    }

    try {
      await sourceRefDatasource.deleteRemoteLinkSource(previousSourceRef);
      if (previousSourceRef.provider == ClipStorageConstants.providerServer &&
          previousSourceRef.ownerScope ==
              ClipStorageConstants.ownerScopeAppAccount) {
        await firestoreMetadataDatasource.deleteLibraryClipDoc(
          previousSourceRef.ownerKey,
          previousSourceRef.remoteDocId,
        );
      }
    } catch (e, st) {
      AppLogger.w(
        '[Clip][Storage] previous-remote-delete failed clipId=$clipId remoteDocId=${previousSourceRef.remoteDocId}',
        error: e,
        stackTrace: st,
      );
    }
  }
}
