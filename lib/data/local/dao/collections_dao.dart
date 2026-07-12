import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/collections.dart';
import '../tables/clips.dart';
import '../tables/segments.dart';
import '../tables/tags.dart';
import '../tables/clip_tags.dart';
import '../tables/recent_clip_views.dart';

part 'collections_dao.g.dart';

@DriftAccessor(tables: [Collections, Clips, Segments, Tags, ClipTags, RecentClipViews])
class CollectionsDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionsDaoMixin {
  CollectionsDao(super.db);

  // All collections
  Future<List<Collection>> fetchAll() => select(collections).get();
  Stream<List<Collection>> watchAll() => select(collections).watch();

  // Find or create collection by (name, storageMode)
  Future<Collection> findOrCreate(
    String name,
    String storageMode, {
    String? remoteId,
  }) async {
    final existing = await (select(collections)
          ..where(
            (c) => c.name.equals(name) & c.storageMode.equals(storageMode),
          )
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;
    final id = await into(collections).insert(
      CollectionsCompanion.insert(
        name: name,
        storageMode: Value(storageMode),
        remoteId: Value(remoteId),
      ),
    );
    return (select(collections)..where((c) => c.id.equals(id))).getSingle();
  }

  Future<Collection?> findById(int id) => (select(collections)
        ..where((c) => c.id.equals(id))
        ..limit(1))
      .getSingleOrNull();

  Future<Collection?> findByRemoteId(String remoteId) => (select(collections)
        ..where((c) => c.remoteId.equals(remoteId))
        ..limit(1))
      .getSingleOrNull();

  Future<Collection?> findByNameAndStorageMode(String name, String storageMode) =>
      (select(collections)
            ..where(
              (c) => c.name.equals(name) & c.storageMode.equals(storageMode),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<void> updateName(int id, String name) =>
      (update(collections)..where((c) => c.id.equals(id)))
          .write(CollectionsCompanion(name: Value(name)));

  Future<void> updateRemoteId(int id, String? remoteId) =>
      (update(collections)..where((c) => c.id.equals(id)))
          .write(CollectionsCompanion(remoteId: Value(remoteId)));

  // Collection names for a given storageMode (for autocomplete)
  Future<List<String>> fetchAllNames(String storageMode) async {
    final rows = await (select(collections)
          ..where((c) => c.storageMode.equals(storageMode)))
        .get();
    return rows.map((c) => c.name).toList();
  }

  // Delete collection if it has no clips
  Future<void> pruneIfEmpty(int collectionId) async {
    final clips = await (select(db.clips)
          ..where((c) => c.collectionId.equals(collectionId)))
        .get();
    if (clips.isEmpty) {
      // group_collections가 이 콜렉션을 참조하는 채로 두면 FK 제약(REFERENCES
      // collections (id), ON DELETE 지정 없음) 때문에 아래 delete가 그대로
      // 예외를 던진다 — 그룹에 속한 콜렉션이 클립 이동으로 비어도 삭제되지
      // 않던 원인이 이것이었다.
      await (delete(db.groupCollections)
            ..where((gc) => gc.collectionId.equals(collectionId)))
          .go();
      await (delete(collections)..where((c) => c.id.equals(collectionId))).go();
    }
  }
}
