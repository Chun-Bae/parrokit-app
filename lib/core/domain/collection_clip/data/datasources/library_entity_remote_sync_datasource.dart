// ============================================================================
// lib/core/collection_media/data/datasources/library_entity_remote_sync_datasource.dart
// ============================================================================
//
// [역할]
// 그룹/콜렉션처럼 "이름을 가진 라이브러리 엔티티"를 서버(Firestore)·
// 클라우드(Google Drive)에 독립적으로 동기화하는 범용 datasource.
// kind 파라미터('groups'/'collections')로 그룹과 콜렉션을 동시에 다뤄서
// 저장위치×엔티티 조합별로 거의 같은 코드를 4벌 만들지 않습니다.
//
// 클립 자체의 원격 동기화(clip_remote_library_sync_datasource.dart)와는
// 별개입니다 — 이 파일은 그룹/콜렉션 "구조" 자체를 다루고, 클립 동기화는
// 여전히 콜렉션 이름/remoteId를 참고 정보로만 사용합니다.
//
// [레이어]
// Core > Collection Media > Data > Datasources
// ============================================================================

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'clip_firestore_metadata_datasource.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';

class LibraryEntityRemoteSyncDatasource {
  final ClipFirestoreMetadataDatasource firestoreMetadataDatasource;
  final GoogleDriveStorageService googleDriveStorageService;

  LibraryEntityRemoteSyncDatasource(
    this.firestoreMetadataDatasource,
    this.googleDriveStorageService,
  );

  // ─────────────────────────────────────────────────────────────────
  // Server (Firestore): users/{uid}/namespaces/library/{kind}/{remoteId}
  // ─────────────────────────────────────────────────────────────────

  Future<void> upsertServerEntity({
    required String uid,
    required String kind,
    required String remoteId,
    required Map<String, dynamic> fields,
  }) async {
    if (uid.isEmpty || remoteId.isEmpty) return;
    await firestoreMetadataDatasource
        .libraryCollectionRef(uid, kind)
        .doc(remoteId)
        .set(fields, SetOptions(merge: true));
  }

  Future<void> deleteServerEntity({
    required String uid,
    required String kind,
    required String remoteId,
  }) async {
    if (uid.isEmpty || remoteId.isEmpty) return;
    await firestoreMetadataDatasource
        .libraryCollectionRef(uid, kind)
        .doc(remoteId)
        .delete();
  }

  Future<List<MapEntry<String, Map<String, dynamic>>>> listServerEntities({
    required String uid,
    required String kind,
  }) async {
    final snapshot =
        await firestoreMetadataDatasource.libraryCollectionRef(uid, kind).get();
    return snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  // Cloud (Google Drive): Parrokit/{kind}/{remoteId}.json
  // ─────────────────────────────────────────────────────────────────

  Future<void> upsertCloudEntity({
    required String kind,
    required String remoteId,
    required Map<String, dynamic> fields,
  }) async {
    await googleDriveStorageService.upsertJsonFile(
      storagePath: '$kind/$remoteId.json',
      content: fields,
    );
  }

  Future<void> deleteCloudEntity({
    required String kind,
    required String remoteId,
  }) async {
    final files = await googleDriveStorageService.listFilesInFolderPath([kind]);
    final fileId = files['$remoteId.json'];
    if (fileId == null) return;
    await googleDriveStorageService.deleteFile(fileId);
  }

  Future<Map<String, Map<String, dynamic>>> listCloudEntities(
    String kind,
  ) async {
    final files = await googleDriveStorageService.listFilesInFolderPath([kind]);
    final result = <String, Map<String, dynamic>>{};
    for (final entry in files.entries) {
      if (!entry.key.endsWith('.json')) continue;
      final remoteId =
          entry.key.substring(0, entry.key.length - '.json'.length);
      final content =
          await googleDriveStorageService.downloadFileContent(entry.value);
      if (content == null) continue;
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          result[remoteId] = decoded;
        }
      } catch (_) {
        continue;
      }
    }
    return result;
  }
}
