import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/groups.dart';

part 'groups_dao.g.dart';

@DriftAccessor(tables: [Groups])
class GroupsDao extends DatabaseAccessor<AppDatabase> with _$GroupsDaoMixin {
  GroupsDao(super.db);

  Future<List<Group>> getAllGroups(String storageMode) => (select(groups)
        ..where((g) => g.storageMode.equals(storageMode))
        ..orderBy([(g) => OrderingTerm.asc(g.name)]))
      .get();

  Future<int> insertGroup(String name, String storageMode,
          {String? remoteId}) =>
      into(groups).insert(GroupsCompanion.insert(
        name: name,
        storageMode: Value(storageMode),
        remoteId: Value(remoteId),
      ));

  Future<void> deleteGroupById(int id) =>
      (delete(groups)..where((g) => g.id.equals(id))).go();

  Future<Group?> findById(int id) => (select(groups)
        ..where((g) => g.id.equals(id))
        ..limit(1))
      .getSingleOrNull();

  Future<Group?> findByRemoteId(String remoteId) => (select(groups)
        ..where((g) => g.remoteId.equals(remoteId))
        ..limit(1))
      .getSingleOrNull();

  Future<Group?> findByNameAndStorageMode(String name, String storageMode) =>
      (select(groups)
            ..where(
              (g) => g.name.equals(name) & g.storageMode.equals(storageMode),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<void> updateName(int id, String name) =>
      (update(groups)..where((g) => g.id.equals(id)))
          .write(GroupsCompanion(name: Value(name)));

  Future<void> updateRemoteId(int id, String? remoteId) =>
      (update(groups)..where((g) => g.id.equals(id)))
          .write(GroupsCompanion(remoteId: Value(remoteId)));
}
