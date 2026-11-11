// Drift DB 엔진 & schemaVersion

// lib/data/local/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/collections.dart';
import 'tables/clips.dart';
import 'tables/segments.dart';
import 'tables/tags.dart';
import 'tables/clip_tags.dart';
import 'tables/recent_clip_views.dart';
import 'tables/groups.dart';
import 'tables/group_collections.dart';
import 'tables/clip_source_refs.dart';
import 'tables/clip_cache_entries.dart';

import 'dao/collections_dao.dart';
import 'dao/groups_dao.dart';
import 'migrations/migration_v2_to_v3.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Groups,
    Collections,
    Clips,
    Segments,
    Tags,
    ClipTags,
    RecentClipViews,
    GroupCollections,
    ClipSourceRefs,
    ClipCacheEntries,
  ],
  daos: [
    GroupsDao,
    CollectionsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// 테스트용. 메모리 DB 등 다른 실행기를 끼울 때 쓴다.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // 외래 키 검사 비활성화
          await customStatement('PRAGMA foreign_keys = OFF');

          if (from < 2) {
            // v1 -> v2 migration (none for now)
          }
          if (from < 3) {
            await migrateV2ToV3(m, this);
          }
        },
        beforeOpen: (details) async {
          // 외래 키 검사 활성화
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _open() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'app.db'));
      return NativeDatabase.createInBackground(file);
    });
