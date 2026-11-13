// 편집 저장이 재생용 절대경로를 DB에 써서, 앱 폴더 경로가 바뀌면(다시 설치·
// 업데이트) 로컬 클립이 '로컬 파일을 찾을 수 없습니다'가 되던 문제(5차).
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/utils/clip_path_utils.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/content-studio/captioning/data/services/clip_load_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docs);
  final String docs;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
}

void main() {
  group('resolveAgainstDocuments', () {
    const now = '/data/Application/NEW/Documents';
    bool Function(String) existing(Set<String> files) => files.contains;

    test('상대경로는 지금 Documents와 합친다', () {
      expect(
          ClipPathUtils.resolveAgainstDocuments('videos/a.mp4', now, (_) => false),
          '$now/videos/a.mp4');
    });

    test('예전 앱 폴더 절대경로에 파일이 없으면 지금 Documents 아래 같은 자리를 쓴다', () {
      expect(
        ClipPathUtils.resolveAgainstDocuments(
            '/data/Application/OLD/Documents/videos/a.mp4',
            now,
            existing({'$now/videos/a.mp4'})),
        '$now/videos/a.mp4',
      );
    });

    test('절대경로에 파일이 있으면 그대로, 어디에도 없으면 원래 값', () {
      const old = '/data/Application/OLD/Documents/videos/a.mp4';
      expect(ClipPathUtils.resolveAgainstDocuments(old, now, existing({old})),
          old);
      expect(ClipPathUtils.resolveAgainstDocuments(old, now, existing({})), old);
      expect(
          ClipPathUtils.resolveAgainstDocuments(
              '/tmp/picked.mp4', now, existing({})),
          '/tmp/picked.mp4');
    });
  });

  group('편집 저장', () {
    late Directory root;
    late String docs;
    late AppDatabase db;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('clip_edit_path');
      docs = '${root.path}/Documents';
      PathProviderPlatform.instance = _FakePathProvider(docs);
      Directory('$docs/videos').createSync(recursive: true);
      Directory('$docs/media/thumbnails').createSync(recursive: true);
      File('$docs/videos/a.mp4').writeAsBytesSync(List.filled(10, 1));
      File('$docs/media/thumbnails/clip.jpg').writeAsBytesSync([1]);
      db = AppDatabase.withExecutor(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });

    Future<int> insertClip(String filePath,
            {String storageMode = 'local', int bytes = 10}) =>
        db.into(db.clips).insert(ClipsCompanion.insert(
              title: '처음 제목',
              filePath: filePath,
              sourceFilePath: Value(filePath),
              thumbnailFilePath: const Value('media/thumbnails/clip.jpg'),
              storageMode: Value(storageMode),
              storageBytes: Value(bytes),
              durationMs: 1000,
            ));

    test('편집 불러오기는 재생용 절대경로가 아니라 DB의 상대경로를 기존 파일로 넘긴다',
        () async {
      final id = await insertClip('videos/a.mp4');
      final result =
          await ClipLoadService(clipProvider: ClipProvider(db)).loadForEdit(id);

      expect(result.formData.filePath, '$docs/videos/a.mp4');
      expect(result.mode.existingFilePath, 'videos/a.mp4');
    });

    test('영상을 바꾸지 않은 저장은 경로·크기를 그대로 두고 제목만 바꾼다', () async {
      final id = await insertClip('videos/a.mp4');
      await ClipProvider(db).service.updateMedia(
            clipId: id,
            collectionName: null,
            clipTitle: '새 제목',
            filePath: 'videos/a.mp4',
            durationMs: 1000,
            segments: const [],
            tags: null,
          );
      final row =
          await (db.select(db.clips)..where((c) => c.id.equals(id))).getSingle();
      expect(row.title, '새 제목');
      expect(row.filePath, 'videos/a.mp4');
      expect(row.sourceFilePath, 'videos/a.mp4');
      expect(row.storageBytes, 10);
    });

    test('경로가 빈 Drive 클립을 편집해도 크기가 0으로 덮이지 않는다', () async {
      final id = await insertClip('', storageMode: 'gdrive', bytes: 500);
      await ClipProvider(db).service.updateMedia(
            clipId: id,
            collectionName: null,
            clipTitle: '새 제목',
            filePath: '',
            durationMs: 1000,
            segments: const [],
            tags: null,
          );
      final row =
          await (db.select(db.clips)..where((c) => c.id.equals(id))).getSingle();
      expect(row.storageBytes, 500);
      expect(row.thumbnailFilePath, 'media/thumbnails/clip.jpg');
    });

    test('예전 앱 폴더 절대경로로 저장된 클립도 지금 앱 폴더에서 연다', () async {
      final id = await insertClip(
          '/old/Application/OLD-UUID/Documents/videos/a.mp4');
      final view = await ClipProvider(db).fetchClipById(id);
      expect(view!.clip.filePath, '$docs/videos/a.mp4');
    });
  });
}
