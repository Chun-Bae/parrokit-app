// ============================================================================
// lib/core/collection_media/data/datasources/clip_cloud_metadata_datasource.dart
// ============================================================================
//
// [역할]
// Google Drive에 올라가는 clips/{remoteDocId}/metadata.json 내용을 빌드하는
// datasource.
//
// [레이어]
// Core > Collection Media > Data > Datasources
// ============================================================================

import 'package:drift/drift.dart';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'clip_detail_query_datasource.dart';

class ClipCloudMetadataDatasource {
  final AppDatabase db;
  final ClipDetailQueryDatasource detailQueryDatasource;

  ClipCloudMetadataDatasource(this.db, this.detailQueryDatasource);

  Future<Map<String, dynamic>> buildCloudClipMetadata({
    required Clip clip,
    required String remoteDocId,
    required String ownerKey,
    required String storagePath,
    required String? thumbnailStoragePath,
    required int storageBytes,
  }) async {
    final segments = await detailQueryDatasource.segmentsForClip(clip.id);
    final tagNames = await detailQueryDatasource.tagNamesForClip(clip.id);
    final collection = clip.collectionId == null
        ? null
        : await (db.select(db.collections)
              ..where((c) => c.id.equals(clip.collectionId!))
              ..limit(1))
            .getSingleOrNull();
    final groupNames = await groupNamesForCollection(clip.collectionId);

    return {
      'schemaVersion': 1,
      'remoteDocId': remoteDocId,
      'localId': clip.id,
      'title': clip.title,
      'durationMs': clip.durationMs,
      'storageBytes': storageBytes,
      'storageMode': ClipStorageConstants.providerGoogleDrive,
      'provider': ClipStorageConstants.providerGoogleDrive,
      'ownerScope': ClipStorageConstants.ownerScopeCloudAccount,
      'ownerKey': ownerKey,
      'storagePath': storagePath,
      'thumbnailStoragePath': thumbnailStoragePath,
      // 다른 기기에서 pull sync로 받아올 때 콜렉션에 자동으로 넣어주기
      // 위한 최소 정보. collectionRemoteId가 있으면 정확히 매칭되고(콜렉션
      // 자체가 독립 동기화된 경우), 없으면 collectionName으로 폴백한다.
      // 그룹/콜렉션 구조 자체를 옮길 때 그룹까지 따라가지는 않는다.
      if (collection != null) 'collectionName': collection.name,
      if (collection?.remoteId != null)
        'collectionRemoteId': collection!.remoteId,
      // 참고용 정보일 뿐 pull sync에서 자동으로 적용하지 않는다 — 그룹은
      // 저장위치별로 독립된 개념이라 이동/당겨오기 시 그대로 따라가지
      // 않는다.
      if (groupNames.isNotEmpty) 'groupNames': groupNames,
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
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<List<String>> groupNamesForCollection(int? collectionId) async {
    if (collectionId == null) return const [];
    final query = db.select(db.groupCollections).join([
      innerJoin(
        db.groups,
        db.groups.id.equalsExp(db.groupCollections.groupId),
      ),
    ])
      ..where(db.groupCollections.collectionId.equals(collectionId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(db.groups).name).toList();
  }
}
