// 폴더 안의 폴더(이름 경로 '여행/일본', b073544f)가 서버(Firestore)에서 받아올 때
// 그대로 돌아오는지 본다(5차 9번). 저장 형식은 바꾸지 않았으므로, 기존 경로
// (collectionName → collections.name)만으로 트리가 다시 만들어져야 한다.
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_cloud_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_detail_query_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_firestore_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_remote_library_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_source_ref_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/repositories/clip_repository_impl.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_thumbnail_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_item_query_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_file_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/collection_group_mirror_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_remote_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_sync_coordinator.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/remote_doc_id_resolver.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:parrokit/core/infrastructure/services/backup_service.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:path/path.dart' as p;
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

  test('앱 백업(zip)에 넣었다 꺼내도 폴더 경로 이름이 그대로다', () async {
    final root = Directory.systemTemp.createTempSync('nested_folder_backup');
    addTearDown(() => root.deleteSync(recursive: true));
    final dbFile = File(p.join(root.path, 'app.db'));
    final fileDb = AppDatabase.withExecutor(NativeDatabase(dbFile));
    for (final name in ['여행', '여행/일본', '여행/일본/오사카', '일상회화']) {
      await fileDb.collectionsDao.findOrCreate(name, 'local');
    }
    await fileDb.close();

    final media = Directory(p.join(root.path, 'media'))..createSync();
    final zipPath = p.join(root.path, 'backup.zip');
    BackupService.compressBackup(BackupCompressParams(
      zipPath: zipPath,
      dbPath: dbFile.path,
      dbRelativePath: 'db/app.db',
      mediaPath: media.path,
      filePaths: const [],
      mediaRelativeDir: 'media',
      timestamp: '2026-11-13T00:00:00.000',
    ));

    final zip = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
    final restored = File(p.join(root.path, 'restored.db'))
      ..writeAsBytesSync(zip.findFile('db/app.db')!.content as List<int>);
    final restoredDb = AppDatabase.withExecutor(NativeDatabase(restored));
    addTearDown(restoredDb.close);
    final names =
        (await restoredDb.select(restoredDb.collections).get()).map((c) => c.name);
    expect(names, containsAll(['여행', '여행/일본', '여행/일본/오사카', '일상회화']));
  });

  LibraryEntitySyncCoordinator coordinatorFor(AppDatabase target) {
    final meta = ClipFirestoreMetadataDatasource(target, firestore: firestore);
    final drive = GoogleDriveStorageService();
    return LibraryEntitySyncCoordinator(
        target, LibraryEntityRemoteSyncDatasource(meta, drive), RemoteDocIdResolver());
  }

  group('폴더 이름 바꾸기', () {
    test('경로 계산', () {
      String? r(String name, String from, String to) =>
          LibraryEntitySyncCoordinator.renamedFolderPath(name, from, to);
      expect(r('여행/일본', '여행', '여행2'), '여행2/일본');
      expect(r('여행/일본/오사카', '여행/일본', '일본'), '일본/오사카');
      expect(r(' 여행 / 일본 ', '여행', '여행2'), '여행2/일본');
      expect(r('여행', '여행', '여행2'), isNull); // 자기 자신은 따로 바꾼다
      expect(r('여행가방', '여행', '여행2'), isNull); // 앞글자만 같은 다른 폴더
      expect(r('여행/일본', '여행', '여행'), isNull);
    });

    test('위 폴더 이름을 바꾸면 하위 폴더가 따라오고, 다른 위치·다른 폴더는 그대로', () async {
      final trip = await db.collectionsDao.findOrCreate('여행', 'local');
      await db.collectionsDao.findOrCreate('여행/일본', 'local');
      await db.collectionsDao.findOrCreate('여행/일본/오사카', 'local');
      await db.collectionsDao.findOrCreate('여행가방', 'local');
      // 다른 저장 위치의 같은 경로는 이 화면(위치별 폴더)에서 바꾸지 않는다.
      await db.collectionsDao.findOrCreate('여행/일본', 'gdrive');

      await coordinatorFor(db).renameCollection(trip.id, '해외여행');

      final local = (await db.select(db.collections).get())
          .where((c) => c.storageMode == 'local')
          .map((c) => c.name)
          .toSet();
      expect(local, {'해외여행', '해외여행/일본', '해외여행/일본/오사카', '여행가방'});
      final drive = (await db.select(db.collections).get())
          .where((c) => c.storageMode == 'gdrive')
          .map((c) => c.name);
      expect(drive, ['여행/일본']);
    });
  });

  test('클립을 다른 저장 위치로 옮기면 폴더 경로 이름이 따라간다', () async {
    final server = await db.collectionsDao.findOrCreate('여행/일본', 'server');
    final mirror = CollectionGroupMirrorDatasource(db, coordinatorFor(db));
    // 목적지에 같은 이름이 없으면 같은 경로 이름으로 만든다(로컬은 원격 없음).
    final newId = await mirror.mirrorCollectionForClip(
      currentCollectionId: server.id,
      destinationStorageMode: 'local',
    );
    final created = await db.collectionsDao.findById(newId!);
    expect(created!.name, '여행/일본');
    expect(created.storageMode, 'local');
    // 다시 옮기면 같은 폴더를 쓴다.
    expect(
        await mirror.mirrorCollectionForClip(
            currentCollectionId: server.id, destinationStorageMode: 'local'),
        newId);
  });

  test('하위 폴더의 마지막 클립을 지우면 그 폴더만 정리되고 위·옆 폴더는 남는다', () async {
    final drive = GoogleDriveStorageService();
    final sourceRef = ClipSourceRefDatasource(db, drive);
    final thumbs = ClipThumbnailDatasource(db, sourceRef, drive);
    final repo = ClipRepositoryImpl(
      db: db,
      sourceRefDatasource: sourceRef,
      thumbnailDatasource: thumbs,
      fileSyncDatasource: ClipFileSyncDatasource(db, sourceRef, drive),
      itemQueryDatasource: ClipItemQueryDatasource(db, sourceRef, thumbs),
      firestoreMetadataDatasource:
          ClipFirestoreMetadataDatasource(db, firestore: firestore),
      libraryEntitySyncCoordinator: coordinatorFor(db),
    );
    Future<int> clipIn(String folder) async {
      final c = await db.collectionsDao.findOrCreate(folder, 'local');
      return db.into(db.clips).insert(ClipsCompanion.insert(
            collectionId: Value(c.id),
            title: folder,
            filePath: '',
            durationMs: 1000,
          ));
    }

    await clipIn('여행');
    final osaka = await clipIn('여행/일본/오사카');
    await clipIn('여행/일본');
    await clipIn('여행/중국');

    expect(await repo.deleteClipById(osaka), isTrue);

    final names = (await db.select(db.collections).get()).map((c) => c.name).toSet();
    expect(names, {'여행', '여행/일본', '여행/중국'});
    final (roots, byPath) = await treeFromDb();
    expect(roots.single.totalCount, 3);
    expect(byPath['여행/일본']!.children, isEmpty);
  });
}
