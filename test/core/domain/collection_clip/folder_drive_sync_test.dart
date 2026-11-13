// Drive(gdrive) 폴더 이름 바꾸기·지우기가 다른 기기로 퍼지는지 본다(5차 9번).
// 실제 Drive 대신 메모리 가짜를 쓴다. 파일 모양(Parrokit/{kind}/{remoteId}.json)은
// 앱 코드가 정한 그대로 거친다.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_firestore_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_remote_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_sync_coordinator.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/remote_doc_id_resolver.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:parrokit/data/local/app_database.dart';

/// 경로 → (파일 id, 내용). 폴더 경로는 'kind', 파일 이름은 'remoteId.json'.
class _MemoryDrive extends GoogleDriveStorageService {
  final Map<String, (String, String)> files = {};
  var _next = 0;

  @override
  Future<GoogleDriveJsonUploadResult> upsertJsonFile({
    required String storagePath,
    required Map<String, dynamic> content,
    Map<String, String>? appProperties,
  }) async {
    final id = files[storagePath]?.$1 ?? 'f${_next++}';
    files[storagePath] = (id, jsonEncode(content));
    return GoogleDriveJsonUploadResult(
        fileId: id,
        fileName: storagePath.split('/').last,
        folderId: 'folder',
        accountKey: 'acct');
  }

  @override
  Future<Map<String, String>> listFilesInFolderPath(
      List<String> folderSegments) async {
    final prefix = '${folderSegments.join('/')}/';
    return {
      for (final e in files.entries)
        if (e.key.startsWith(prefix)) e.key.substring(prefix.length): e.value.$1,
    };
  }

  @override
  Future<String?> downloadFileContent(String fileId) async {
    for (final e in files.values) {
      if (e.$1 == fileId) return e.$2;
    }
    return null;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    files.removeWhere((_, v) => v.$1 == fileId);
  }
}

void main() {
  late _MemoryDrive drive;
  late AppDatabase dbA;
  late AppDatabase dbB;
  late LibraryEntitySyncCoordinator a;
  late LibraryEntitySyncCoordinator b;

  LibraryEntitySyncCoordinator device(AppDatabase db) =>
      LibraryEntitySyncCoordinator(
        db,
        LibraryEntityRemoteSyncDatasource(
            ClipFirestoreMetadataDatasource(db,
                firestore: FakeFirebaseFirestore()),
            drive),
        RemoteDocIdResolver(),
        currentUid: () => 'u1',
      );

  setUp(() {
    drive = _MemoryDrive();
    dbA = AppDatabase.withExecutor(NativeDatabase.memory());
    dbB = AppDatabase.withExecutor(NativeDatabase.memory());
    a = device(dbA);
    b = device(dbB);
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  Future<Set<String>> names(AppDatabase db) async =>
      (await db.select(db.collections).get()).map((c) => c.name).toSet();

  test('Drive 폴더 이름 바꾸기(하위 폴더 포함)가 다른 기기에 퍼진다', () async {
    final parent = await a.createCollection('여행', 'gdrive');
    await a.createCollection('여행/일본', 'gdrive');
    await b.pullCloud();
    expect(await names(dbB), {'여행', '여행/일본'});

    await a.renameCollection(parent.id, '해외여행');
    await b.pullCloud();
    expect(await names(dbB), {'해외여행', '해외여행/일본'});
    // Drive 파일 모양은 그대로(경로 이름은 json의 name에만 있다).
    expect(drive.files.keys.every((k) => k.startsWith('collections/')), isTrue);
  });

  test('Drive에서 지운 빈 폴더는 다른 기기에서도 정리된다', () async {
    final japan = await a.createCollection('여행/일본', 'gdrive');
    await a.createCollection('여행/미국', 'gdrive');
    await b.pullCloud();

    await a.deleteCollection(japan.id);
    await b.reconcileCloudAfterClips();
    expect(await names(dbB), {'여행/미국'});
  });
}
