// 폴더 이름 바꾸기가 서버를 거쳐 다른 기기로 퍼지는지 본다(5차 9번).
// 기기 둘이 같은 Firestore(가짜)를 쓰고, 한쪽에서 바꾼 이름이 다른 쪽 pull로
// 들어오는지 확인한다. 저장 형식(collections 문서의 name)은 그대로다.
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_firestore_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_remote_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_sync_coordinator.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/remote_doc_id_resolver.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:parrokit/data/local/app_database.dart';

void main() {
  const uid = 'u1';
  late FakeFirebaseFirestore firestore;
  late AppDatabase dbA;
  late AppDatabase dbB;
  late LibraryEntitySyncCoordinator a;
  late LibraryEntitySyncCoordinator b;

  LibraryEntitySyncCoordinator device(AppDatabase db) {
    final meta = ClipFirestoreMetadataDatasource(db, firestore: firestore);
    return LibraryEntitySyncCoordinator(
      db,
      LibraryEntityRemoteSyncDatasource(meta, GoogleDriveStorageService()),
      RemoteDocIdResolver(),
      currentUid: () => uid,
    );
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
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

  test('한 기기에서 바꾼 폴더 이름(하위 폴더 포함)이 다른 기기에 퍼진다', () async {
    final parent = await a.createCollection('여행', 'server');
    await a.createCollection('여행/일본', 'server');
    await b.pullServer(uid);
    expect(await names(dbB), {'여행', '여행/일본'});

    await a.renameCollection(parent.id, '해외여행');
    expect(await names(dbA), {'해외여행', '해외여행/일본'});

    await b.pullServer(uid);
    expect(await names(dbB), {'해외여행', '해외여행/일본'});
  });

  test('이름을 바꾼 뒤 처음 받는 기기도 바뀐 이름으로 받는다', () async {
    final parent = await a.createCollection('여행', 'server');
    await a.createCollection('여행/일본', 'server');
    await a.renameCollection(parent.id, '해외여행');

    await b.pullServer(uid);
    expect(await names(dbB), {'해외여행', '해외여행/일본'});
  });

  test('그룹 이름 바꾸기도 다른 기기에 퍼진다', () async {
    final group = await a.createGroup('영어', 'server');
    await b.pullServer(uid);
    await a.renameGroup(group.id, '영어 회화');
    await b.pullServer(uid);
    final groups = (await dbB.select(dbB.groups).get()).map((g) => g.name);
    expect(groups, ['영어 회화']);
  });

  test('로그인하지 않았으면 서버에 쓰지 않는다', () async {
    final offline = LibraryEntitySyncCoordinator(
      dbA,
      LibraryEntityRemoteSyncDatasource(
          ClipFirestoreMetadataDatasource(dbA, firestore: firestore),
          GoogleDriveStorageService()),
      RemoteDocIdResolver(),
      currentUid: () => null,
    );
    final before = firestore.dump();
    await offline.createCollection('여행', 'server');
    expect(firestore.dump(), before);
  });
}
