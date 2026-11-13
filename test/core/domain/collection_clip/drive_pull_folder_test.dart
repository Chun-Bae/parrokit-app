// Drive(gdrive) 클립 받기(pullCloudClips)가 폴더 경로 이름을 그대로 가져오는지 본다
// (5차 9번). 실제 Drive 대신 메모리 가짜를 쓰고, metadata.json은 앱 코드
// (buildCloudClipMetadata)가 만든 것을 그대로 쓴다. 저장 형식은 바꾸지 않는다.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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
import 'package:parrokit/data/local/app_database.dart';

/// clips/{remoteDocId}/ 폴더 하나 = 클립 하나. 파일 이름 → (파일 id, 내용).
class _ClipDrive extends GoogleDriveStorageService {
  final Map<String, Map<String, (String, String)>> folders = {};
  final deleted = <String>[];
  var _next = 0;

  void putClip(String remoteDocId, Map<String, dynamic>? metadata,
      {bool withVideo = true}) {
    folders[remoteDocId] = {
      if (metadata != null)
        'metadata.json': ('m${_next++}', jsonEncode(metadata)),
      if (withVideo) '$remoteDocId.mp4': ('v${_next++}', ''),
    };
  }

  @override
  Future<List<(String, String)>> listClipFolders() async =>
      [for (final id in folders.keys) (id, 'folder-$id')];

  @override
  Future<Map<String, String>> listFilesInFolder(String folderId) async {
    final files = folders[folderId.replaceFirst('folder-', '')] ?? const {};
    return {for (final e in files.entries) e.key: e.value.$1};
  }

  @override
  Future<String?> downloadFileContent(String fileId) async {
    for (final files in folders.values) {
      for (final f in files.values) {
        if (f.$1 == fileId) return f.$2;
      }
    }
    return null;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    deleted.add(fileId);
    folders.remove(fileId.replaceFirst('folder-', ''));
  }

  @override
  Future<Map<String, String>> listFilesInFolderPath(
          List<String> folderSegments) async =>
      const {};
}

void main() {
  const account = 'me@example.com';
  late _ClipDrive drive;
  late AppDatabase source;
  late AppDatabase target;
  late ClipRemoteLibrarySyncDatasource sync;

  setUp(() {
    drive = _ClipDrive();
    source = AppDatabase.withExecutor(NativeDatabase.memory());
    target = AppDatabase.withExecutor(NativeDatabase.memory());
    final meta = ClipFirestoreMetadataDatasource(target,
        firestore: FakeFirebaseFirestore());
    sync = ClipRemoteLibrarySyncDatasource(
      target,
      meta,
      ClipSourceRefDatasource(target, drive),
      drive,
      LibraryEntitySyncCoordinator(
        target,
        LibraryEntityRemoteSyncDatasource(meta, drive),
        RemoteDocIdResolver(),
        currentUid: () => 'u1',
      ),
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  /// 보내는 기기에서 [folder] 폴더에 클립을 만들고 앱 코드로 metadata.json을 만든다.
  Future<Map<String, dynamic>> metadataFor(String remoteDocId, String folder,
      {String? collectionRemoteId}) async {
    final collection = await source.collectionsDao
        .findOrCreate(folder, 'gdrive', remoteId: collectionRemoteId);
    final clipId = await source.into(source.clips).insert(ClipsCompanion.insert(
          collectionId: Value(collection.id),
          title: '클립 $remoteDocId',
          filePath: '',
          durationMs: 2000,
        ));
    await source.into(source.segments).insert(SegmentsCompanion.insert(
        clipId: clipId,
        startMs: 0,
        endMs: 1000,
        original: 'Hello',
        pron: '헬로',
        trans: '안녕'));
    final clip = await (source.select(source.clips)
          ..where((c) => c.id.equals(clipId)))
        .getSingle();
    return ClipCloudMetadataDatasource(
            source, ClipDetailQueryDatasource(source))
        .buildCloudClipMetadata(
      clip: clip,
      remoteDocId: remoteDocId,
      ownerKey: account,
      storagePath: 'Parrokit/clips/$remoteDocId/$remoteDocId.mp4',
      thumbnailStoragePath: null,
      storageBytes: 10,
    );
  }

  Future<Map<String, int>> clipCountByFolder() async {
    final collections = {
      for (final c in await target.select(target.collections).get()) c.id: c
    };
    final counts = <String, int>{};
    for (final clip in await target.select(target.clips).get()) {
      final c = collections[clip.collectionId]!;
      expect(c.storageMode, 'gdrive');
      counts[c.name] = (counts[c.name] ?? 0) + 1;
    }
    return counts;
  }

  test('Drive에서 받은 클립이 같은 경로 폴더로 들어가고 구간도 함께 온다', () async {
    drive.putClip('r1', await metadataFor('r1', '여행/일본'));
    drive.putClip('r2', await metadataFor('r2', '여행/일본/오사카'));
    drive.putClip('r3', await metadataFor('r3', '일상회화'));

    expect(await sync.pullCloudClips(account), 3);
    expect(await clipCountByFolder(),
        {'여행/일본': 1, '여행/일본/오사카': 1, '일상회화': 1});

    final segments = await target.select(target.segments).get();
    expect(segments.map((s) => s.original), everyElement('Hello'));
    final refs = await target.select(target.clipSourceRefs).get();
    expect(refs.map((r) => r.cloudFolderId).toSet(),
        {'folder-r1', 'folder-r2', 'folder-r3'});
  });

  test('다시 받아도 클립·폴더가 늘지 않는다', () async {
    drive.putClip('r1', await metadataFor('r1', '여행/일본'));
    await sync.pullCloudClips(account);
    final collectionsBefore = await target.select(target.collections).get();

    expect(await sync.pullCloudClips(account), 0);
    expect(await target.select(target.clips).get(), hasLength(1));
    expect(await target.select(target.collections).get(),
        hasLength(collectionsBefore.length));
  });

  test('영상 없는 고아 폴더는 클립으로 만들지 않고 치우며, metadata 없는 폴더는 건너뛴다',
      () async {
    drive.putClip('ok', await metadataFor('ok', '여행/일본'));
    drive.putClip('orphan', await metadataFor('orphan', '여행/일본'),
        withVideo: false);
    drive.putClip('nometa', null);

    expect(await sync.pullCloudClips(account), 1);
    expect(drive.deleted, ['folder-orphan']);
    expect(drive.folders.containsKey('nometa'), isTrue);
    expect(await clipCountByFolder(), {'여행/일본': 1});
  });

  test('Drive에서 지워진 클립은 정리되고, 빈 하위 폴더만 사라지며 위 폴더는 남는다',
      () async {
    drive.putClip('r1', await metadataFor('r1', '여행'));
    drive.putClip('r2', await metadataFor('r2', '여행/일본'));
    await sync.pullCloudClips(account);

    drive.folders.remove('r2');
    expect(await sync.pullCloudClips(account), 1);
    expect(await clipCountByFolder(), {'여행': 1});
    final names =
        (await target.select(target.collections).get()).map((c) => c.name);
    expect(names, ['여행']);
  });

  test('폴더 원격 id가 맞으면 이 기기에서 바꾼 이름의 폴더로 들어간다', () async {
    // 이 기기는 같은 폴더(원격 id c1)를 이미 '해외여행/일본'으로 바꿔 두었다.
    await target.collectionsDao
        .findOrCreate('해외여행/일본', 'gdrive', remoteId: 'c1');
    drive.putClip(
        'r1', await metadataFor('r1', '여행/일본', collectionRemoteId: 'c1'));

    await sync.pullCloudClips(account);
    expect(await clipCountByFolder(), {'해외여행/일본': 1});
  });

  test('폴더 이름이 없는 예전 metadata는 미분류로 들어간다', () async {
    final meta = await metadataFor('old', '여행')
      ..remove('collectionName');
    drive.putClip('old', meta);

    await sync.pullCloudClips(account);
    expect(await clipCountByFolder(), {'미분류': 1});
  });

  test('깊은 경로·특수문자·이모지·긴 이름이 그대로 돌아온다', () async {
    final long = '아' * 200;
    final names = [
      '1/2/3/4/5/6',
      '여행 & 맛집/일본(오사카)/#1 "best"',
      '🇯🇵 일본어/아니메 🎬',
      long,
    ];
    for (var i = 0; i < names.length; i++) {
      drive.putClip('r$i', await metadataFor('r$i', names[i]));
    }
    await sync.pullCloudClips(account);
    expect(await clipCountByFolder(), {for (final n in names) n: 1});
  });

  test('대소문자만 다른 폴더는 따로, 앞뒤 공백은 떼어 같은 폴더로', () async {
    drive.putClip('a', await metadataFor('a', 'Travel'));
    drive.putClip('b', await metadataFor('b', 'travel'));
    final padded = await metadataFor('c', 'Travel')
      ..['collectionName'] = '  Travel  ';
    drive.putClip('c', padded);

    await sync.pullCloudClips(account);
    expect(await clipCountByFolder(), {'Travel': 2, 'travel': 1});
  });

  test('같은 이름의 로컬 폴더가 있어도 Drive 클립은 Drive 폴더로 들어간다', () async {
    await target.collectionsDao.findOrCreate('여행/일본', 'local');
    drive.putClip('r1', await metadataFor('r1', '여행/일본'));

    await sync.pullCloudClips(account);
    // clipCountByFolder가 클립의 폴더가 gdrive인지 확인한다.
    expect(await clipCountByFolder(), {'여행/일본': 1});
    final modes = (await target.select(target.collections).get())
        .map((c) => (c.name, c.storageMode))
        .toSet();
    expect(modes, {('여행/일본', 'local'), ('여행/일본', 'gdrive')});
  });
}
