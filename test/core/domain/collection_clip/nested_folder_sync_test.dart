// 폴더 안의 폴더(이름 경로 '여행/일본', b073544f)가 서버(Firestore)에서 받아올 때
// 그대로 돌아오는지 본다(5차 9번). 저장 형식은 바꾸지 않았으므로, 기존 경로
// (collectionName → collections.name)만으로 트리가 다시 만들어져야 한다.
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_cloud_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_detail_query_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_firestore_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_remote_library_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_source_ref_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_remote_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_sync_coordinator.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/remote_doc_id_resolver.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/library/presentation/folder_tree.dart';

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late ClipRemoteLibrarySyncDatasource sync;
  const uid = 'u1';

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    final meta = ClipFirestoreMetadataDatasource(db, firestore: firestore);
    final drive = GoogleDriveStorageService();
    sync = ClipRemoteLibrarySyncDatasource(
      db,
      meta,
      ClipSourceRefDatasource(db, drive),
      drive,
      LibraryEntitySyncCoordinator(
        db,
        LibraryEntityRemoteSyncDatasource(meta, drive),
        RemoteDocIdResolver(),
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> serverClip(String docId, String? collectionName) => firestore
      .collection('users')
      .doc(uid)
      .collection('namespaces')
      .doc('library')
      .collection('clips')
      .doc(docId)
      .set({
        'remoteDocId': docId,
        'title': docId,
        'durationMs': 1000,
        if (collectionName != null) 'collectionName': collectionName,
        'segments': const [],
        'tags': const [],
      });

  Future<(List<ClipFolder>, Map<String, ClipFolder>)> treeFromDb() async {
    final collections = await db.select(db.collections).get();
    final clips = await db.select(db.clips).get();
    final counts = <int, int>{};
    for (final c in clips) {
      if (c.collectionId != null) {
        counts[c.collectionId!] = (counts[c.collectionId!] ?? 0) + 1;
      }
    }
    return buildFolderTree([for (final c in collections) (c.id, c.name)], counts);
  }

  test('서버에서 받은 경로 이름 폴더가 같은 트리로 돌아온다', () async {
    await serverClip('a', '여행/일본');
    await serverClip('b', '여행/일본/오사카');
    await serverClip('c', '여행');
    await serverClip('d', '일상회화');

    expect(await sync.pullServerClips(uid), 4);

    final names = (await db.select(db.collections).get()).map((c) => c.name);
    expect(names, containsAll(['여행/일본', '여행/일본/오사카', '여행', '일상회화']));
    final (roots, byPath) = await treeFromDb();
    expect(roots.map((f) => f.name), ['여행', '일상회화']);
    expect(byPath['여행']!.totalCount, 3);
    expect(byPath['여행/일본']!.children.single.name, '오사카');
  });

  test('같은 경로의 클립은 한 폴더로 모이고 다시 받아도 늘지 않는다', () async {
    await serverClip('a', '여행/일본');
    await serverClip('b', '여행/일본');
    await sync.pullServerClips(uid);
    expect(await sync.pullServerClips(uid), 0);

    final collections = await db.select(db.collections).get();
    expect(collections.where((c) => c.name == '여행/일본'), hasLength(1));
    final (_, byPath) = await treeFromDb();
    expect(byPath['여행/일본']!.directCount, 2);
  });

  test("'/' 없는 예전 이름과 폴더 없는 클립은 예전처럼 들어온다", () async {
    await serverClip('a', '일상회화');
    await serverClip('b', null);
    await sync.pullServerClips(uid);

    final names = (await db.select(db.collections).get()).map((c) => c.name);
    expect(names, containsAll(['일상회화', '미분류']));
    final (roots, _) = await treeFromDb();
    expect(roots.every((f) => f.children.isEmpty), isTrue);
  });

  test('경로 앞뒤 공백은 저장 이름에서는 잘리고, 화면 트리에서는 같은 폴더가 된다', () async {
    await serverClip('a', '  여행/일본  ');
    await serverClip('b', '여행 / 일본');
    await sync.pullServerClips(uid);

    final names = (await db.select(db.collections).get()).map((c) => c.name).toSet();
    // 저장된 이름은 받은 그대로(앞뒤 공백만 자름). 형식을 바꾸지 않는다.
    expect(names, {'여행/일본', '여행 / 일본'});
    final (_, byPath) = await treeFromDb();
    expect(byPath['여행/일본']!.directCount, 2);
    expect(byPath['여행/일본']!.collectionIds, hasLength(2));
  });

  test('Drive 메타데이터에 경로 이름이 그대로 실리고 다른 기기에서 같은 트리로 받는다', () async {
    // 이 기기: '여행/일본' 폴더의 클립
    final collection = await db.collectionsDao.findOrCreate('여행/일본', 'gdrive');
    final clipId = await db.into(db.clips).insert(ClipsCompanion.insert(
          collectionId: Value(collection.id),
          title: '오사카 역',
          filePath: '',
          durationMs: 1000,
        ));
    final clip = await (db.select(db.clips)..where((c) => c.id.equals(clipId)))
        .getSingle();
    final meta = await ClipCloudMetadataDatasource(db, ClipDetailQueryDatasource(db))
        .buildCloudClipMetadata(
      clip: clip,
      remoteDocId: 'r1',
      ownerKey: 'me@example.com',
      storagePath: 'Parrokit/clips/r1.mp4',
      thumbnailStoragePath: null,
      storageBytes: 1,
    );
    expect(meta['collectionName'], '여행/일본');

    // 다른 기기: 같은 필드(collectionName)로 받는다. 서버 받기와 같은 삽입 경로.
    final other = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(other.close);
    final otherFs = FakeFirebaseFirestore();
    await otherFs
        .collection('users')
        .doc(uid)
        .collection('namespaces')
        .doc('library')
        .collection('clips')
        .doc('r1')
        .set({...meta, 'remoteDocId': 'r1'});
    final otherMeta = ClipFirestoreMetadataDatasource(other, firestore: otherFs);
    final drive = GoogleDriveStorageService();
    await ClipRemoteLibrarySyncDatasource(
      other,
      otherMeta,
      ClipSourceRefDatasource(other, drive),
      drive,
      LibraryEntitySyncCoordinator(other,
          LibraryEntityRemoteSyncDatasource(otherMeta, drive), RemoteDocIdResolver()),
    ).pullServerClips(uid);
    final names = (await other.select(other.collections).get()).map((c) => c.name);
    expect(names, ['여행/일본']);
  });
}
