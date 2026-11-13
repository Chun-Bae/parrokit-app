// ============================================================================
// lib/core/collection_media/data/datasources/library_entity_sync_coordinator.dart
// ============================================================================
//
// [역할]
// 그룹/콜렉션 생성·이름변경·삭제·pull 진입점에서 로컬 DB 반영과 원격
// (서버/클라우드) 동기화를 한 번에 처리하는 조정자. storageMode가
// local이면 원격 호출 없이 로컬만 갱신합니다.
//
// collection_group_mirror_datasource.dart와는 역할이 다릅니다 — 그쪽은
// "클립이 이동할 때 콜렉션을 이름으로 매칭"하는 것이고, 이쪽은 "그룹/
// 콜렉션 자체의 CRUD를 원격에 반영"하는 것입니다. 클립 이동/pull 시
// 그룹 정보는 여전히 사용하지 않는다는 기존 설계는 그대로 유지됩니다.
//
// [레이어]
// Core > Collection Media > Data > Datasources
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:drift/drift.dart';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'library_entity_remote_sync_datasource.dart';
import 'remote_doc_id_resolver.dart';

class LibraryEntitySyncCoordinator {
  final AppDatabase db;
  final LibraryEntityRemoteSyncDatasource remoteSyncDatasource;
  final RemoteDocIdResolver remoteDocIdResolver;

  LibraryEntitySyncCoordinator(
    this.db,
    this.remoteSyncDatasource,
    this.remoteDocIdResolver, {
    String? Function()? currentUid,
  }) : _currentUid =
            currentUid ?? (() => fb.FirebaseAuth.instance.currentUser?.uid);

  /// 지금 로그인한 계정 uid. 테스트에서 FirebaseAuth 없이 서버 경로를 돌리려고
  /// 바꿔 끼울 수 있다(5차 9번). 앱에서는 기본값(FirebaseAuth)을 쓴다.
  final String? Function() _currentUid;

  static const _kindGroups = 'groups';
  static const _kindCollections = 'collections';

  // ─────────────────────────────────────────────────────────────────
  // Create
  // ─────────────────────────────────────────────────────────────────

  /// 원격 업로드를 먼저 끝내고 나서 로컬에 insert합니다. 순서를 반대로
  /// 하면(로컬 먼저) 업로드가 끝나기 전 짧은 사이에 동시에 도는 pull의
  /// reconcile 로직이 "아직 원격에 안 보이는 방금 만든 그룹"을 "원격에서
  /// 지워짐"으로 오인해서 지워버리는 레이스가 생깁니다.
  Future<Group> createGroup(String name, String storageMode) async {
    final remoteId = _needsRemoteId(storageMode) ? remoteDocIdResolver.newClipDocId() : null;
    if (remoteId != null) {
      await _upsertRemoteEntity(
        storageMode: storageMode,
        kind: _kindGroups,
        remoteId: remoteId,
        fields: {'name': name},
      );
    }
    final id = await db.groupsDao.insertGroup(name, storageMode, remoteId: remoteId);
    return Group(id: id, name: name, storageMode: storageMode, remoteId: remoteId);
  }

  /// createGroup과 같은 이유로 원격 업로드를 먼저 끝내고 로컬에 insert합니다.
  Future<Collection> createCollection(
    String name,
    String storageMode, {
    List<int> groupIds = const [],
  }) async {
    final remoteId = _needsRemoteId(storageMode) ? remoteDocIdResolver.newClipDocId() : null;
    if (remoteId != null) {
      final groupRemoteIds = await _remoteIdsForGroups(groupIds);
      await _upsertRemoteEntity(
        storageMode: storageMode,
        kind: _kindCollections,
        remoteId: remoteId,
        fields: {
          'name': name,
          if (groupRemoteIds.isNotEmpty) 'groupRemoteIds': groupRemoteIds,
        },
      );
    }
    final id = await db.into(db.collections).insert(
          CollectionsCompanion.insert(
            name: name,
            storageMode: Value(storageMode),
            remoteId: Value(remoteId),
          ),
        );
    return Collection(id: id, name: name, storageMode: storageMode, remoteId: remoteId);
  }

  // ─────────────────────────────────────────────────────────────────
  // Rename
  // ─────────────────────────────────────────────────────────────────

  Future<void> renameGroup(int id, String newName) async {
    final group = await db.groupsDao.findById(id);
    if (group == null) return;
    await db.groupsDao.updateName(id, newName);
    final remoteId = group.remoteId;
    if (remoteId != null) {
      await _upsertRemoteEntity(
        storageMode: group.storageMode,
        kind: _kindGroups,
        remoteId: remoteId,
        fields: {'name': newName},
      );
    }
  }

  /// 폴더 안의 폴더(이름 경로 '여행/일본', 5차)를 위해, 이름을 바꾸면 같은 저장
  /// 위치에서 그 경로 아래에 있는 폴더 이름 앞부분도 함께 바꾼다. 예전에는 '여행'을
  /// '여행2'로 바꾸면 '여행/일본'이 남아 폴더가 둘로 갈라졌다. 저장 형식은 그대로고
  /// 바뀌는 것은 이름 값뿐이며, 원격 동기화는 폴더마다 원래 경로를 탄다.
  Future<void> renameCollection(int id, String newName) async {
    final collection = await db.collectionsDao.findById(id);
    if (collection == null) return;
    final children = <(int, String)>[];
    for (final other in await db.collectionsDao.fetchAll()) {
      if (other.id == id || other.storageMode != collection.storageMode) {
        continue;
      }
      final renamed = renamedFolderPath(other.name, collection.name, newName);
      if (renamed != null) children.add((other.id, renamed));
    }
    await _renameOne(collection, newName);
    for (final (childId, childName) in children) {
      final child = await db.collectionsDao.findById(childId);
      if (child != null) await _renameOne(child, childName);
    }
  }

  /// [name]이 [oldPath] 아래 폴더면 [newPath] 아래로 옮긴 이름, 아니면 null.
  /// 경로 비교는 칸마다 앞뒤 공백을 뗀 모양으로 한다. 예:
  /// renamedFolderPath('여행/일본', '여행', '여행2') == '여행2/일본'
  static String? renamedFolderPath(String name, String oldPath, String newPath) {
    String norm(String v) => v
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('/');
    final from = norm(oldPath);
    final to = norm(newPath);
    final current = norm(name);
    if (from.isEmpty || to.isEmpty || from == to) return null;
    if (!current.startsWith('$from/')) return null;
    return '$to${current.substring(from.length)}';
  }

  Future<void> _renameOne(Collection collection, String newName) async {
    final id = collection.id;
    await db.collectionsDao.updateName(id, newName);
    final remoteId = collection.remoteId;
    if (remoteId != null) {
      final groupRemoteIds = await _remoteIdsForGroups(await _groupIdsForCollection(id));
      await _upsertRemoteEntity(
        storageMode: collection.storageMode,
        kind: _kindCollections,
        remoteId: remoteId,
        fields: {
          'name': newName,
          if (groupRemoteIds.isNotEmpty) 'groupRemoteIds': groupRemoteIds,
        },
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Delete (원격 삭제만 담당 — 로컬 삭제는 기존 호출부가 그대로 수행)
  // ─────────────────────────────────────────────────────────────────

  Future<void> deleteGroup(int id) async {
    final group = await db.groupsDao.findById(id);
    final remoteId = group?.remoteId;
    if (group == null || remoteId == null) return;
    await _deleteRemoteEntity(
      storageMode: group.storageMode,
      kind: _kindGroups,
      remoteId: remoteId,
    );
  }

  Future<void> deleteCollection(int id) async {
    final collection = await db.collectionsDao.findById(id);
    final remoteId = collection?.remoteId;
    if (collection == null || remoteId == null) return;
    await _deleteRemoteEntity(
      storageMode: collection.storageMode,
      kind: _kindCollections,
      remoteId: remoteId,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Pull (다른 기기가 만든 빈 그룹/콜렉션도 로컬로 당겨오기)
  // ─────────────────────────────────────────────────────────────────

  /// 반환값은 이번 pull로 로컬에 새로 생긴 그룹/콜렉션 개수입니다 (이미
  /// 있던 걸 remoteId만 붙여 "입양"한 경우는 세지 않음 — 목록에 새로
  /// 보일 게 없으므로 UI 새로고침을 유발할 필요가 없음).
  Future<int> pullServer(String uid) async {
    final groupDocs = await remoteSyncDatasource.listServerEntities(uid: uid, kind: _kindGroups);
    final collectionDocs =
        await remoteSyncDatasource.listServerEntities(uid: uid, kind: _kindCollections);
    return _pullGroupsAndCollections(
      storageMode: ClipStorageConstants.storageModeServer,
      groupEntities: {for (final e in groupDocs) e.key: e.value},
      collectionEntities: {for (final e in collectionDocs) e.key: e.value},
    );
  }

  Future<int> pullCloud() async {
    final groupEntities = await remoteSyncDatasource.listCloudEntities(_kindGroups);
    final collectionEntities = await remoteSyncDatasource.listCloudEntities(_kindCollections);
    return _pullGroupsAndCollections(
      storageMode: ClipStorageConstants.storageModeGoogleDrive,
      groupEntities: groupEntities,
      collectionEntities: collectionEntities,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Reconcile (원격이 source of truth — 원격에서 지워진 그룹/콜렉션은
  // 로컬에서도 지운다). 클립 pull이 먼저 끝나서 참조하는 클립이 정리된
  // 뒤에 호출해야 한다 — 콜렉션/그룹을 클립이 아직 참조 중이면 FK 제약
  // 때문에 삭제할 수 없어서, 그런 경우는 건드리지 않고 다음 정리 때
  // 다시 시도한다.
  // ─────────────────────────────────────────────────────────────────

  /// 반환값은 이번에 정리된(삭제된) 그룹/콜렉션 개수입니다.
  Future<int> reconcileServerAfterClips(String uid) async {
    final groupDocs = await remoteSyncDatasource.listServerEntities(uid: uid, kind: _kindGroups);
    final collectionDocs =
        await remoteSyncDatasource.listServerEntities(uid: uid, kind: _kindCollections);
    return _reconcileGoneEntities(
      storageMode: ClipStorageConstants.storageModeServer,
      remoteGroupIds: groupDocs.map((e) => e.key).toSet(),
      remoteCollectionIds: collectionDocs.map((e) => e.key).toSet(),
    );
  }

  Future<int> reconcileCloudAfterClips() async {
    final groupEntities = await remoteSyncDatasource.listCloudEntities(_kindGroups);
    final collectionEntities = await remoteSyncDatasource.listCloudEntities(_kindCollections);
    return _reconcileGoneEntities(
      storageMode: ClipStorageConstants.storageModeGoogleDrive,
      remoteGroupIds: groupEntities.keys.toSet(),
      remoteCollectionIds: collectionEntities.keys.toSet(),
    );
  }

  Future<int> _reconcileGoneEntities({
    required String storageMode,
    required Set<String> remoteGroupIds,
    required Set<String> remoteCollectionIds,
  }) async {
    var removedCount = 0;

    final localCollections = await (db.select(db.collections)
          ..where(
            (c) => c.storageMode.equals(storageMode) & c.remoteId.isNotNull(),
          ))
        .get();
    for (final collection in localCollections) {
      final remoteId = collection.remoteId;
      if (remoteId == null || remoteCollectionIds.contains(remoteId)) continue;
      final stillHasClips = await (db.select(db.clips)
            ..where((c) => c.collectionId.equals(collection.id))
            ..limit(1))
          .getSingleOrNull();
      if (stillHasClips != null) continue;
      await (db.delete(db.groupCollections)
            ..where((gc) => gc.collectionId.equals(collection.id)))
          .go();
      await (db.delete(db.collections)..where((c) => c.id.equals(collection.id)))
          .go();
      removedCount++;
    }

    final localGroups = await (db.select(db.groups)
          ..where((g) => g.storageMode.equals(storageMode) & g.remoteId.isNotNull()))
        .get();
    for (final group in localGroups) {
      final remoteId = group.remoteId;
      if (remoteId == null || remoteGroupIds.contains(remoteId)) continue;
      final stillHasCollections = await (db.select(db.groupCollections)
            ..where((gc) => gc.groupId.equals(group.id))
            ..limit(1))
          .getSingleOrNull();
      if (stillHasCollections != null) continue;
      await (db.delete(db.groups)..where((g) => g.id.equals(group.id))).go();
      removedCount++;
    }

    return removedCount;
  }

  Future<int> _pullGroupsAndCollections({
    required String storageMode,
    required Map<String, Map<String, dynamic>> groupEntities,
    required Map<String, Map<String, dynamic>> collectionEntities,
  }) async {
    var createdCount = 0;
    final remoteIdToLocalGroupId = <String, int>{};
    for (final entry in groupEntities.entries) {
      final name = entry.value['name'] as String?;
      if (name == null || name.trim().isEmpty) continue;
      final (localId, created) = await _adoptOrCreateGroup(
        remoteId: entry.key,
        name: name.trim(),
        storageMode: storageMode,
      );
      remoteIdToLocalGroupId[entry.key] = localId;
      if (created) createdCount++;
    }

    for (final entry in collectionEntities.entries) {
      final name = entry.value['name'] as String?;
      if (name == null || name.trim().isEmpty) continue;
      final (localCollectionId, created) = await _adoptOrCreateCollection(
        remoteId: entry.key,
        name: name.trim(),
        storageMode: storageMode,
      );
      if (created) createdCount++;
      final groupRemoteIds =
          (entry.value['groupRemoteIds'] as List?)?.whereType<String>() ?? const [];
      for (final groupRemoteId in groupRemoteIds) {
        final localGroupId = remoteIdToLocalGroupId[groupRemoteId];
        if (localGroupId == null) continue;
        await db.into(db.groupCollections).insert(
              GroupCollectionsCompanion.insert(
                groupId: localGroupId,
                collectionId: localCollectionId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }
    return createdCount;
  }

  Future<(int, bool)> _adoptOrCreateGroup({
    required String remoteId,
    required String name,
    required String storageMode,
  }) async {
    final byRemoteId = await db.groupsDao.findByRemoteId(remoteId);
    if (byRemoteId != null) {
      // 다른 기기에서 이름을 바꿨으면 서버 이름을 따른다(5차 9번). 예전엔
      // 이미 받은 그룹은 이름을 그대로 둬서 바꾼 이름이 퍼지지 않았다.
      if (byRemoteId.name != name) {
        await db.groupsDao.updateName(byRemoteId.id, name);
      }
      return (byRemoteId.id, false);
    }

    final unsynced = await db.groupsDao.findByNameAndStorageMode(name, storageMode);
    if (unsynced != null && unsynced.remoteId == null) {
      await db.groupsDao.updateRemoteId(unsynced.id, remoteId);
      return (unsynced.id, false);
    }

    final id = await db.groupsDao.insertGroup(name, storageMode, remoteId: remoteId);
    return (id, true);
  }

  Future<(int, bool)> _adoptOrCreateCollection({
    required String remoteId,
    required String name,
    required String storageMode,
  }) async {
    final byRemoteId = await db.collectionsDao.findByRemoteId(remoteId);
    if (byRemoteId != null) {
      // 폴더(컬렉션)도 같다. '여행' → '해외여행'이면 하위 '여행/일본'도 서버에서
      // 각자 바뀐 이름으로 오므로 여기서 하나씩 맞춰진다.
      if (byRemoteId.name != name) {
        await db.collectionsDao.updateName(byRemoteId.id, name);
      }
      return (byRemoteId.id, false);
    }

    final unsynced = await db.collectionsDao.findByNameAndStorageMode(name, storageMode);
    if (unsynced != null && unsynced.remoteId == null) {
      await db.collectionsDao.updateRemoteId(unsynced.id, remoteId);
      return (unsynced.id, false);
    }

    final id = await db.into(db.collections).insert(
          CollectionsCompanion.insert(
            name: name,
            storageMode: Value(storageMode),
            remoteId: Value(remoteId),
          ),
        );
    return (id, true);
  }

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  bool _needsRemoteId(String storageMode) =>
      storageMode == ClipStorageConstants.storageModeServer ||
      storageMode == ClipStorageConstants.storageModeGoogleDrive;

  Future<void> _upsertRemoteEntity({
    required String storageMode,
    required String kind,
    required String remoteId,
    required Map<String, dynamic> fields,
  }) async {
    if (storageMode == ClipStorageConstants.storageModeServer) {
      final uid = _currentUid();
      if (uid == null) return;
      await remoteSyncDatasource.upsertServerEntity(
        uid: uid,
        kind: kind,
        remoteId: remoteId,
        fields: fields,
      );
    } else if (storageMode == ClipStorageConstants.storageModeGoogleDrive) {
      await remoteSyncDatasource.upsertCloudEntity(
        kind: kind,
        remoteId: remoteId,
        fields: fields,
      );
    }
  }

  Future<void> _deleteRemoteEntity({
    required String storageMode,
    required String kind,
    required String remoteId,
  }) async {
    if (storageMode == ClipStorageConstants.storageModeServer) {
      final uid = _currentUid();
      if (uid == null) return;
      await remoteSyncDatasource.deleteServerEntity(uid: uid, kind: kind, remoteId: remoteId);
    } else if (storageMode == ClipStorageConstants.storageModeGoogleDrive) {
      await remoteSyncDatasource.deleteCloudEntity(kind: kind, remoteId: remoteId);
    }
  }

  Future<List<String>> _remoteIdsForGroups(List<int> groupIds) async {
    final remoteIds = <String>[];
    for (final id in groupIds) {
      final group = await db.groupsDao.findById(id);
      final remoteId = group?.remoteId;
      if (remoteId != null) remoteIds.add(remoteId);
    }
    return remoteIds;
  }

  Future<List<int>> _groupIdsForCollection(int collectionId) async {
    final rows = await (db.select(db.groupCollections)
          ..where((gc) => gc.collectionId.equals(collectionId)))
        .get();
    return rows.map((r) => r.groupId).toList();
  }
}
