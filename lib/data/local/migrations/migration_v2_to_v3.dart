import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../app_database.dart';

/// Schema Version 2 -> 3 마이그레이션
/// - Groups 테이블 생성 (storageMode, remoteId 포함)
/// - 다대다 매핑을 위한 GroupCollections 테이블 생성
/// - clip 원본/캐시 스키마 생성
/// - Collections에 storageMode, remoteId 컬럼 추가
/// - 기존에 로컬/서버/gdrive 클립이 섞여 있던 콜렉션을 storageMode별로 분리
///   (같은 이름의 콜렉션/그룹을 목적지 storageMode에서 찾거나 새로 만들고,
///   그 모드의 클립들을 재배정)
///
/// 주의 — 마지막 항목(storageMode별 분리)은 실제로 한 번도 실행되지 않는다.
/// 아래 UPDATE가 WHERE 없이 모든 클립의 storage_mode를 'local'로 덮어쓴 뒤에
/// 그 값을 읽어 모드를 가르기 때문에, distinctModes는 늘 {'local'}이고
/// `if (... == 'local') continue;`에서 전부 빠진다. 그래서 분리 루프와 그
/// 뒤의 빈 콜렉션 정리까지 도달하지 않는다.
///
/// v2에는 클립별 storageMode 컬럼 자체가 없었으니(이 마이그레이션이 추가한다)
/// v2 클립은 모두 로컬이고, 가를 것이 애초에 없었던 것으로 보인다. 지우지
/// 않고 남겨 둔다 — 이미 사용자 기기에서 돌아간 마이그레이션이라, 판단은
/// 이 코드를 쓴 사람이 하는 게 맞다.
Future<void> migrateV2ToV3(Migrator m, AppDatabase db) async {
  await m.createTable(db.groups);
  await m.createTable(db.groupCollections);
  await m.createTable(db.clipSourceRefs);
  await m.createTable(db.clipCacheEntries);
  await m.addColumn(db.collections, db.collections.storageMode);
  await m.addColumn(db.collections, db.collections.remoteId);

  await m.addColumn(db.clips, db.clips.sourceFilePath);
  await m.addColumn(db.clips, db.clips.thumbnailFilePath);
  await m.addColumn(db.clips, db.clips.storageMode);
  await m.addColumn(db.clips, db.clips.storageBytes);
  await m.addColumn(db.clips, db.clips.ownerScope);
  await m.addColumn(db.clips, db.clips.ownerKey);

  await db.customStatement(
    """
    UPDATE clips
    SET source_file_path = file_path,
        storage_mode = 'local',
        owner_scope = 'device',
        owner_key = NULL
    """,
  );

  final dir = await getApplicationDocumentsDirectory();
  final clips = await db.select(db.clips).get();
  for (final clip in clips) {
    final path = clip.filePath.startsWith('/')
        ? clip.filePath
        : '${dir.path}/${clip.filePath}';
    final file = File(path);
    final bytes = await file.exists() ? await file.length() : 0;
    await (db.update(db.clips)..where((c) => c.id.equals(clip.id))).write(
      ClipsCompanion(storageBytes: Value(bytes)),
    );
  }

  final collections = await db.select(db.collections).get();
  final emptiedCollectionIds = <int>{};

  for (final collection in collections) {
    final clipsInCollection = await (db.select(db.clips)
          ..where((c) => c.collectionId.equals(collection.id)))
        .get();
    if (clipsInCollection.isEmpty) continue;

    final distinctModes = clipsInCollection.map((c) => c.storageMode).toSet();
    if (distinctModes.length == 1 && distinctModes.single == 'local') {
      continue;
    }

    for (final mode in distinctModes.where((mode) => mode != 'local')) {
      final destCollectionId =
          await _findOrCreateCollection(db, collection.name, mode);

      await (db.update(db.clips)
            ..where(
              (c) =>
                  c.collectionId.equals(collection.id) &
                  c.storageMode.equals(mode),
            ))
          .write(ClipsCompanion(collectionId: Value(destCollectionId)));

      final groupLinks = await (db.select(db.groupCollections)
            ..where((gc) => gc.collectionId.equals(collection.id)))
          .get();
      for (final link in groupLinks) {
        final sourceGroup = await (db.select(db.groups)
              ..where((g) => g.id.equals(link.groupId))
              ..limit(1))
            .getSingleOrNull();
        if (sourceGroup == null) continue;

        final destGroupId =
            await _findOrCreateGroup(db, sourceGroup.name, mode);
        await db.into(db.groupCollections).insert(
              GroupCollectionsCompanion.insert(
                groupId: destGroupId,
                collectionId: destCollectionId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }

    final remaining = await (db.select(db.clips)
          ..where((c) => c.collectionId.equals(collection.id)))
        .get();
    if (remaining.isEmpty) {
      emptiedCollectionIds.add(collection.id);
    }
  }

  if (emptiedCollectionIds.isNotEmpty) {
    await (db.delete(db.groupCollections)
          ..where((gc) => gc.collectionId.isIn(emptiedCollectionIds)))
        .go();
    await (db.delete(db.collections)
          ..where((c) => c.id.isIn(emptiedCollectionIds)))
        .go();
  }
}

Future<int> _findOrCreateCollection(
  AppDatabase db,
  String name,
  String storageMode,
) async {
  final existing = await (db.select(db.collections)
        ..where(
          (c) => c.name.equals(name) & c.storageMode.equals(storageMode),
        )
        ..limit(1))
      .getSingleOrNull();
  if (existing != null) return existing.id;
  return db.into(db.collections).insert(
        CollectionsCompanion.insert(
          name: name,
          storageMode: Value(storageMode),
        ),
      );
}

Future<int> _findOrCreateGroup(
  AppDatabase db,
  String name,
  String storageMode,
) async {
  final existing = await (db.select(db.groups)
        ..where(
          (g) => g.name.equals(name) & g.storageMode.equals(storageMode),
        )
        ..limit(1))
      .getSingleOrNull();
  if (existing != null) return existing.id;
  return db.into(db.groups).insert(
        GroupsCompanion.insert(name: name, storageMode: Value(storageMode)),
      );
}
