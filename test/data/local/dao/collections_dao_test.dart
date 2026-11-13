import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/repositories/group_repository_impl.dart';
import 'package:parrokit/data/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('CollectionsDao.findOrCreate', () {
    test('없으면 만들고, 두 번째 호출은 같은 콜렉션을 돌려준다', () async {
      final first = await db.collectionsDao.findOrCreate('여행', 'local');
      final second = await db.collectionsDao.findOrCreate('여행', 'local');

      expect(second.id, first.id);
      expect(await db.collectionsDao.fetchAll(), hasLength(1));
    });

    test('storageMode가 다르면 이름이 같아도 따로 만든다', () async {
      final local = await db.collectionsDao.findOrCreate('여행', 'local');
      final server = await db.collectionsDao.findOrCreate('여행', 'server');

      expect(server.id, isNot(local.id));
      expect(await db.collectionsDao.fetchAll(), hasLength(2));
    });

    test('찾은 콜렉션에 원격 id가 없으면 넘겨준 값을 붙인다', () async {
      final created = await db.collectionsDao.findOrCreate('여행', 'server');
      expect(created.remoteId, isNull);

      final linked = await db.collectionsDao
          .findOrCreate('여행', 'server', remoteId: 'remote-1');

      expect(linked.id, created.id);
      expect(linked.remoteId, 'remote-1');
      // DB에도 남아야 다음 pull이 findByRemoteId로 바로 찾는다.
      expect(await db.collectionsDao.findByRemoteId('remote-1'), isNotNull);
    });

    test('이미 다른 원격 id가 붙어 있으면 덮어쓰지 않는다', () async {
      await db.collectionsDao
          .findOrCreate('여행', 'server', remoteId: 'remote-1');

      final again = await db.collectionsDao
          .findOrCreate('여행', 'server', remoteId: 'remote-2');

      expect(again.remoteId, 'remote-1');
      expect(await db.collectionsDao.findByRemoteId('remote-2'), isNull);
    });
  });

  group('CollectionsDao.pruneIfEmpty', () {
    test('그룹에 속한 빈 콜렉션도 지운다', () async {
      final collection =
          await db.collectionsDao.findOrCreate('여행', 'local');
      final groupId = await db.groupsDao.insertGroup('올해', 'local');
      await db.into(db.groupCollections).insert(
            GroupCollectionsCompanion.insert(
              groupId: groupId,
              collectionId: collection.id,
            ),
          );

      await db.collectionsDao.pruneIfEmpty(collection.id);

      expect(await db.collectionsDao.fetchAll(), isEmpty);
      expect(await db.select(db.groupCollections).get(), isEmpty);
    });
    test('클립이 남아 있으면 지우지 않는다', () async {
      final collection =
          await db.collectionsDao.findOrCreate('여행', 'local');
      await db.into(db.clips).insert(ClipsCompanion.insert(
          title: 'c',
          filePath: '',
          durationMs: 1000,
          collectionId: Value(collection.id)));

      await db.collectionsDao.pruneIfEmpty(collection.id);

      expect((await db.collectionsDao.fetchAll()).map((c) => c.name), ['여행']);
      expect(await db.select(db.clips).get(), hasLength(1));
    });
  });

  group('GroupRepositoryImpl.deleteGroupById', () {
    test('그룹과 연결만 지우고 안의 콜렉션·클립은 남긴다', () async {
      final repo = GroupRepositoryImpl(db);
      final collection =
          await db.collectionsDao.findOrCreate('여행', 'local');
      await db.into(db.clips).insert(ClipsCompanion.insert(
          title: 'c',
          filePath: '',
          durationMs: 1000,
          collectionId: Value(collection.id)));
      final groupId = await db.groupsDao.insertGroup('올해', 'local');
      final otherGroup = await db.groupsDao.insertGroup('작년', 'local');
      for (final g in [groupId, otherGroup]) {
        await db.into(db.groupCollections).insert(
              GroupCollectionsCompanion.insert(
                  groupId: g, collectionId: collection.id),
            );
      }

      await repo.deleteGroupById(groupId);

      expect((await repo.getAllGroups('local')).map((g) => g.name), ['작년']);
      final links = await db.select(db.groupCollections).get();
      expect(links.map((l) => l.groupId), [otherGroup]);
      expect(await db.collectionsDao.fetchAll(), hasLength(1));
      expect(await db.select(db.clips).get(), hasLength(1));
    });

    test('그룹 목록은 이름 순이고 저장 방식별로 나뉜다', () async {
      final repo = GroupRepositoryImpl(db);
      await db.groupsDao.insertGroup('나', 'local');
      await db.groupsDao.insertGroup('가', 'local');
      await db.groupsDao.insertGroup('다', 'server');

      expect((await repo.getAllGroups('local')).map((g) => g.name), ['가', '나']);
      expect((await repo.getAllGroups('server')).map((g) => g.name), ['다']);
    });
  });
}
