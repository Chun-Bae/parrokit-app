// ============================================================================
// lib/core/collection_media/data/datasources/clip_item_query_datasource.dart
// ============================================================================
//
// [역할]
// 목록 화면에 필요한 ClipItem(클립 + 태그 + 세그먼트 + 썸네일 바이트)을
// 조립하는 datasource. 썸네일은 항상 ClipThumbnailDatasource를 거쳐
// clip.thumbnailFilePath/원격 썸네일 복구 로직을 타도록 합니다.
//
// [레이어]
// Core > Collection Media > Data > Datasources
// ============================================================================

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/domain/collection_clip/data/utils/clip_path_utils.dart';
import 'clip_source_ref_datasource.dart';
import 'clip_thumbnail_datasource.dart';

class ClipItemQueryDatasource {
  final AppDatabase db;
  final ClipSourceRefDatasource sourceRefDatasource;
  final ClipThumbnailDatasource thumbnailDatasource;

  ClipItemQueryDatasource(
    this.db,
    this.sourceRefDatasource,
    this.thumbnailDatasource,
  );

  Future<List<ClipItem>> fetchClipItemsByStorageMode(String storageMode) async {
    final clips = await sourceRefDatasource.visibleClipsByStorageMode(storageMode);
    return buildClipItems(clips);
  }

  Future<List<ClipItem>> fetchCachedRemoteClipItems() async {
    final clips = await _fetchCachedRemoteClips();
    return buildClipItems(clips);
  }

  Future<List<Clip>> _fetchCachedRemoteClips() async {
    final remoteClips = await sourceRefDatasource.visibleRemoteClips();
    final cachedClips = <Clip>[];

    for (final clip in remoteClips) {
      final cacheEntry = await sourceRefDatasource.getCurrentClipCacheEntry(clip);
      if (cacheEntry == null) continue;
      final absPath = await ClipPathUtils.absolutePathFor(cacheEntry.filePath);
      final file = File(absPath);
      if (await file.exists() && await file.length() > 0) {
        cachedClips.add(clip);
      }
    }

    return cachedClips;
  }

  Future<List<ClipItem>> buildClipItems(List<Clip> clips) async {
    final tagsByClip = <int, List<Tag>>{};

    if (clips.isNotEmpty) {
      final clipIds = clips.map((c) => c.id).toList();
      final jt = db.clipTags;
      final rows = await (db.select(db.tags).join([
        innerJoin(jt, jt.tagId.equalsExp(db.tags.id)),
      ])
            ..where(jt.clipId.isIn(clipIds)))
          .get();

      for (final row in rows) {
        final tag = row.readTable(db.tags);
        final ct = row.readTable(jt);
        tagsByClip.putIfAbsent(ct.clipId, () => []).add(tag);
      }
    }

    final items = <ClipItem>[];
    for (final clip in clips) {
      final segments = await (db.select(db.segments)
            ..where((s) => s.clipId.equals(clip.id))
            ..orderBy([(s) => OrderingTerm.asc(s.startMs)]))
          .get();

      Uint8List? thumbBytes = await thumbnailDatasource.loadThumbnailBytes(clip);
      String? previewPath;
      if (thumbBytes == null) {
        previewPath = await _resolveExistingPreviewPath(clip);
      }
      if (previewPath != null && thumbBytes == null) {
        final absPath = await ClipPathUtils.absolutePathFor(previewPath);
        try {
          thumbBytes = await VideoThumbnail.thumbnailData(
            video: absPath,
            imageFormat: ImageFormat.JPEG,
            quality: 70,
            timeMs: 500,
          );
        } catch (_) {
          thumbBytes = null;
        }
      }

      final effectivePath = previewPath ?? clip.filePath;

      items.add(
        ClipItem(
          clip: clip.copyWith(filePath: effectivePath),
          tags: tagsByClip[clip.id] ?? const [],
          segments: segments,
          thumbnail: thumbBytes,
        ),
      );
    }

    return items;
  }

  Future<String?> _resolveExistingPreviewPath(Clip clip) async {
    if (clip.storageMode == ClipStorageConstants.storageModeLocal) {
      final sourcePath = clip.sourceFilePath ?? clip.filePath;
      if (sourcePath.isEmpty) return null;
      final absPath = await ClipPathUtils.absolutePathFor(sourcePath);
      final file = File(absPath);
      return await file.exists() && await file.length() > 0 ? sourcePath : null;
    }

    final cacheEntry = await sourceRefDatasource.getCurrentClipCacheEntry(clip);
    if (cacheEntry == null) return null;

    final absPath = await ClipPathUtils.absolutePathFor(cacheEntry.filePath);
    final file = File(absPath);
    return await file.exists() && await file.length() > 0
        ? cacheEntry.filePath
        : null;
  }
}
