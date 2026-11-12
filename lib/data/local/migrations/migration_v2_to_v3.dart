import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../app_database.dart';

/// Schema Version 2 -> 3 마이그레이션
/// - Groups 테이블 생성 (storageMode, remoteId 포함)
/// - 다대다 매핑을 위한 GroupCollections 테이블 생성
/// - clip 원본/캐시 스키마 생성
/// - Collections에 storageMode, remoteId 컬럼 추가
/// - 클립마다 파일 크기를 재서 storageBytes에 채움
///
/// 전에는 "로컬·서버·gdrive 클립이 섞인 콜렉션을 storageMode별로 분리"하는
/// 64줄이 더 있었다. 그 코드는 한 번도 실행되지 않았다. 아래 UPDATE가 WHERE
/// 없이 모든 클립의 storage_mode를 'local'로 덮어쓴 다음 그 값을 읽어 모드를
/// 갈랐기 때문에, 콜렉션마다 distinctModes가 늘 {'local'}이고
/// `if (distinctModes.single == 'local') continue;`에서 전부 빠졌다. 분리
/// 루프와 그 뒤의 빈 콜렉션 정리, 전용 헬퍼 둘까지 도달한 적이 없다.
///
/// v2에는 클립별 storageMode 컬럼 자체가 없었다. 이 마이그레이션이 그걸
/// 추가한다. 그러니 v2 클립은 모두 로컬이고 가를 것이 애초에 없었다.
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
}
