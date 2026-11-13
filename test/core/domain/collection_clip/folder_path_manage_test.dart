// 새 보관함의 폴더 이름 바꾸기·빈 폴더 지우기(5차). 경로 단위로, 저장 위치와
// 상관없이 하위 폴더까지 함께 다룬다. 저장 형식(collections.name)은 그대로다.
import 'package:drift/drift.dart' show Value;
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
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late LibraryEntitySyncCoordinator coordinator;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    coordinator = LibraryEntitySyncCoordinator(
      db,
      LibraryEntityRemoteSyncDatasource(
          ClipFirestoreMetadataDatasource(db, firestore: firestore),
          GoogleDriveStorageService()),
      RemoteDocIdResolver(),
      currentUid: () => 'u1',
    );
  });
  tearDown(() => db.close());

  Future<Set<String>> names() async =>
      (await db.select(db.collections).get()).map((c) => c.name).toSet();

  Future<void> clipIn(int collectionId) => db.into(db.clips).insert(
      ClipsCompanion.insert(
          title: 'c',
          filePath: '',
          durationMs: 1000,
          collectionId: Value(collectionId)));

  test('이름 바꾸기는 위치가 달라도, 자기 폴더가 없는 상위 폴더여도 하위까지 바꾼다', () async {
    await coordinator.createCollection('여행/일본', 'local');
    await coordinator.createCollection('여행/미국', 'server');
    await coordinator.createCollection('여행행', 'local'); // 이름만 비슷한 폴더
    final changed = await coordinator.renameFolderPath('여행', '해외여행');
    expect(changed, 2);
    expect(await names(), {'해외여행/일본', '해외여행/미국', '여행행'});
    // 서버 폴더는 서버 문서 이름도 바뀐다.
    final docs = await firestore
        .collection('users/u1/namespaces/library/collections')
        .get();
    expect(docs.docs.map((d) => d['name']), contains('해외여행/미국'));
  });

  test('자기 이름과 같은 폴더도 바뀐다', () async {
    await coordinator.createCollection('단어장', 'local');
    await coordinator.createCollection('단어장/동사', 'local');
    await coordinator.renameFolderPath('단어장', '내 단어장');
    expect(await names(), {'내 단어장', '내 단어장/동사'});
  });

  test('빈 폴더는 하위까지 지우고, 클립이 하나라도 있으면 아무것도 지우지 않는다', () async {
    await coordinator.createCollection('빈/하나', 'local');
    await coordinator.createCollection('빈', 'server');
    final keep = await coordinator.createCollection('찬/둘', 'local');
    await clipIn(keep.id);

    expect(await coordinator.deleteEmptyFolderPath('찬'), isFalse);
    expect(await names(), contains('찬/둘'));

    expect(await coordinator.deleteEmptyFolderPath('빈'), isTrue);
    expect(await names(), {'찬/둘'});
    final docs = await firestore
        .collection('users/u1/namespaces/library/collections')
        .get();
    expect(docs.docs, isEmpty, reason: '서버 폴더 문서도 지운다');
  });
}
