// ============================================================================
// lib/core/collection_media/data/datasources/clip_thumbnail_datasource.dart
// ============================================================================
//
// [역할]
// Clip 썸네일 생성(로컬 영상 파일 기준) 및 복구(server/gdrive 원격 썸네일
// 다운로드) 전담 datasource.
//
// gdrive는 영상 스트림에서 바로 썸네일을 뽑을 수 없기 때문에, 업로드 시점에
// 별도로 썸네일 파일을 만들어 함께 올려두고(clip_source_refs.thumbnail*),
// 로컬 캐시가 없을 때는 여기서 원격 썸네일을 내려받아 복구합니다.
// 이 클래스가 유일한 진입점이므로, 화면단 코드는 절대 자체적으로
// VideoThumbnail을 다시 호출하지 말고 이 datasource(ClipRepository 경유)를
// 사용해야 합니다 — 그렇지 않으면 예전에 겪은 "gdrive 클립 썸네일 안 뜨는"
// 버그가 재발합니다.
//
// [레이어]
// Core > Collection Media > Data > Datasources
// ============================================================================

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/domain/collection_clip/data/utils/clip_path_utils.dart';
import 'clip_source_ref_datasource.dart';

class ClipThumbnailDatasource {
  final AppDatabase db;
  final ClipSourceRefDatasource sourceRefDatasource;
  final GoogleDriveStorageService googleDriveStorageService;

  ClipThumbnailDatasource(
    this.db,
    this.sourceRefDatasource,
    this.googleDriveStorageService,
  );

  Future<String?> ensureThumbnailFile({
    required int clipId,
    required String videoPath,
    String? existingThumbnailPath,
    String? remoteDocId,
  }) async {
    if (existingThumbnailPath != null && existingThumbnailPath.isNotEmpty) {
      final existing =
          File(await ClipPathUtils.absolutePathFor(existingThumbnailPath));
      if (await existing.exists() && await existing.length() > 0) {
        return existingThumbnailPath;
      }
    }

    final videoFile = File(await ClipPathUtils.absolutePathFor(videoPath));
    if (!await videoFile.exists()) return null;

    final thumbnailPath = remoteDocId == null || remoteDocId.isEmpty
        ? 'media/thumbnails/clip_$clipId.jpg'
        : 'media/thumbnails/$remoteDocId.jpg';
    final thumbnailFile = File(await ClipPathUtils.absolutePathFor(thumbnailPath));
    await thumbnailFile.parent.create(recursive: true);

    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        quality: 76,
        timeMs: 500,
      );
      if (bytes == null || bytes.isEmpty) return null;
      await thumbnailFile.writeAsBytes(bytes, flush: true);
      return thumbnailPath;
    } catch (e, st) {
      AppLogger.w(
        '[Clip][Thumbnail] generate failed clipId=$clipId',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// clip.thumbnailFilePath(로컬 캐시) -> 원격(server/gdrive) 순으로 썸네일
  /// 바이트를 복구합니다. local/server/gdrive 저장 모드를 모두 올바르게
  /// 처리하는 유일한 진입점입니다.
  Future<Uint8List?> loadThumbnailBytes(Clip clip) async {
    try {
      final thumbnailPath = await _ensureStoredThumbnailPath(clip);
      if (thumbnailPath == null || thumbnailPath.isEmpty) return null;

      final file = File(await ClipPathUtils.absolutePathFor(thumbnailPath));
      if (await file.exists() && await file.length() > 0) {
        return file.readAsBytes();
      }
    } catch (e, st) {
      AppLogger.w(
        '[Clip][Thumbnail] read failed clipId=${clip.id}',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  Future<String?> _ensureStoredThumbnailPath(Clip clip) async {
    final thumbnailPath = clip.thumbnailFilePath;
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final file = File(await ClipPathUtils.absolutePathFor(thumbnailPath));
      if (await file.exists() && await file.length() > 0) {
        return thumbnailPath;
      }
    }

    if (clip.storageMode == ClipStorageConstants.storageModeLocal) {
      final sourcePath = clip.sourceFilePath ?? clip.filePath;
      if (sourcePath.isEmpty) return null;
      final generatedPath = await ensureThumbnailFile(
        clipId: clip.id,
        videoPath: sourcePath,
        existingThumbnailPath: thumbnailPath,
      );
      if (generatedPath != null) {
        await db.update(db.clips).replace(
              clip.copyWith(thumbnailFilePath: Value(generatedPath)),
            );
      }
      return generatedPath;
    }

    final sourceRef = await sourceRefDatasource.getCurrentClipSourceRef(clip);
    if (sourceRef == null) return null;

    final restoredPath = await _restoreRemoteThumbnailFile(sourceRef: sourceRef);
    if (restoredPath == null) return null;

    await db.update(db.clips).replace(
          clip.copyWith(thumbnailFilePath: Value(restoredPath)),
        );
    return restoredPath;
  }

  Future<String?> _restoreRemoteThumbnailFile({
    required ClipSourceRef sourceRef,
  }) async {
    final thumbnailPath = 'media/thumbnails/${sourceRef.remoteDocId}.jpg';
    final destination = File(await ClipPathUtils.absolutePathFor(thumbnailPath));

    try {
      AppLogger.d(
        '[Clip][Thumbnail] remote-download-start clipId=${sourceRef.clipId} provider=${sourceRef.provider} path=$thumbnailPath',
      );
      if (sourceRef.provider == ClipStorageConstants.providerServer) {
        await _restoreServerThumbnailFile(sourceRef, destination);
      } else if (sourceRef.provider == ClipStorageConstants.providerGoogleDrive) {
        await _restoreCloudThumbnailFile(sourceRef, destination);
      } else {
        AppLogger.w(
          '[Clip][Thumbnail] remote-download-skip clipId=${sourceRef.clipId} provider=${sourceRef.provider}',
        );
        return null;
      }

      if (await destination.exists() && await destination.length() > 0) {
        final bytes = await destination.length();
        AppLogger.i(
          '[Clip][Thumbnail] remote-download-success clipId=${sourceRef.clipId} provider=${sourceRef.provider} bytes=$bytes path=$thumbnailPath',
        );
        return thumbnailPath;
      }
      AppLogger.w(
        '[Clip][Thumbnail] remote-download-empty clipId=${sourceRef.clipId} provider=${sourceRef.provider} path=$thumbnailPath',
      );
    } catch (e, st) {
      AppLogger.w(
        '[Clip][Thumbnail] remote-restore failed clipId=${sourceRef.clipId}',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  Future<void> _restoreServerThumbnailFile(
    ClipSourceRef sourceRef,
    File destination,
  ) async {
    final ref = sourceRef.thumbnailStoragePath != null &&
            sourceRef.thumbnailStoragePath!.isNotEmpty
        ? FirebaseStorage.instance.ref(sourceRef.thumbnailStoragePath!)
        : (sourceRef.thumbnailDownloadUrl != null &&
                sourceRef.thumbnailDownloadUrl!.isNotEmpty
            ? FirebaseStorage.instance.refFromURL(sourceRef.thumbnailDownloadUrl!)
            : null);
    if (ref == null) {
      throw StateError('서버 썸네일 경로를 찾을 수 없습니다.');
    }

    await destination.parent.create(recursive: true);
    await ref.writeToFile(destination);
  }

  Future<void> _restoreCloudThumbnailFile(
    ClipSourceRef sourceRef,
    File destination,
  ) async {
    final thumbnailRemoteFileId = sourceRef.thumbnailRemoteFileId;
    if (thumbnailRemoteFileId == null || thumbnailRemoteFileId.isEmpty) {
      throw StateError('클라우드 썸네일 정보를 찾을 수 없습니다.');
    }

    await destination.parent.create(recursive: true);
    await googleDriveStorageService.downloadClipFile(
      fileId: thumbnailRemoteFileId,
      destination: destination,
    );
  }
}
