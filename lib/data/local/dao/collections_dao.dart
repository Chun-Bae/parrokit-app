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

  /// (name, storageMode)로 콜렉션을 찾고 없으면 만든다.
  ///
  /// 찾기와 만들기를 한 트랜잭션에 묶는다. 전에는 나뉘어 있어서, pull 동기화가
  /// 도는 중에 사용자가 같은 이름의 콜렉션에 클립을 넣으면 양쪽이 "없다"를
  /// 보고 각각 insert해 같은 이름의 콜렉션이 둘 생길 수 있었다.
  /// (name, storageMode)에 unique index를 걸면 더 확실하지만 스키마 변경이다.
  Future<Collection> findOrCreate(
    String name,
    String storageMode, {
    String? remoteId,
  }) {
    return transaction(() async {
      final existing = await findByNameAndStorageMode(name, storageMode);
      if (existing != null) {
        // 원격 id를 받아 왔는데 찾은 콜렉션에 아직 없으면 그때 붙여 준다.
        // 전에는 조용히 버려서, 로컬에서 먼저 만든 콜렉션이 원격 문서와
        // 끝까지 연결되지 않았다. 그러면 pull은 매번 이름으로만 찾게 되고,
        // 사용자가 그 콜렉션 이름을 바꾸면 다음 pull이 같은 내용의 콜렉션을
        // 하나 더 만든다.
        // 이미 다른 원격 id가 붙어 있으면 건드리지 않는다.
        if (remoteId != null &&
            remoteId.isNotEmpty &&
            (existing.remoteId == null || existing.remoteId!.isEmpty)) {
          await updateRemoteId(existing.id, remoteId);
          return existing.copyWith(remoteId: Value(remoteId));
        }
        return existing;
      }
      final id = await into(collections).insert(
        CollectionsCompanion.insert(
          name: name,
          storageMode: Value(storageMode),
          remoteId: Value(remoteId),
        ),
      );
      return (select(collections)..where((c) => c.id.equals(id))).getSingle();
    });
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
