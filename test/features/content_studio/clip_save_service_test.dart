// 클립 저장(ClipSaveService)이 어떤 파일 경로를 DB 쪽으로 넘기는지 본다(5차 8번).
// 편집에서 영상을 바꾸지 않았는데 재생용 절대경로가 저장되던 문제(dcc9f22b)를
// 다시 만들지 않게 잡아 둔다.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/content-studio/captioning/data/services/clip_save_service.dart';
import 'package:parrokit/features/content-studio/captioning/data/services/file_staging_service.dart';
import 'package:parrokit/features/content-studio/captioning/domain/models/clip_form_data.dart';
import 'package:parrokit/features/content-studio/captioning/domain/models/edit_mode.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final Directory root;

  @override
  Future<String?> getTemporaryPath() async => '${root.path}/tmp';

  @override
  Future<String?> getApplicationDocumentsPath() async => '${root.path}/docs';
}

/// DB에 쓰지 않고 넘겨받은 값만 적어 둔다.
class _RecordingProvider extends ClipProvider {
  _RecordingProvider(super.db);

  final calls = <(String, int?, String, List<Segment>)>[];

  @override
  Future<void> addClip({
    required String? collectionName,
    required String clipTitle,
    required String filePath,
    required int durationMs,
    required List<Segment> segments,
    required List<String>? tags,
  }) async =>
      calls.add(('add', null, filePath, segments));

  @override
  Future<void> updateClip({
    required int clipId,
    required String? collectionName,
    required String clipTitle,
    required String filePath,
    required int durationMs,
    required List<Segment> segments,
    required List<String>? tags,
    String? storageMode,
  }) async =>
      calls.add(('update', clipId, filePath, segments));
}

void main() {
  late Directory root;
  late AppDatabase db;
  late _RecordingProvider provider;
  late FileStagingService staging;
  late ClipSaveService service;

  const form = ClipFormData(
    clipTitle: '제목',
    durationMs: 3000,
    segments: [
      SegmentInput(
          start: '00:01.250',
          end: '00:02.500',
          original: 'Hi',
          pron: '하이',
          ko: '안녕'),
    ],
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('clip_save');
    Directory('${root.path}/tmp').createSync();
    Directory('${root.path}/docs/videos').createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(root);
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    provider = _RecordingProvider(db);
    staging = FileStagingService();
    service = ClipSaveService(repo: provider, staging: staging);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<String> stage() async {
    final picked = File('${root.path}/picked.mp4')
      ..writeAsBytesSync(List.filled(64, 3));
    return staging.stageFromPath(picked.path);
  }

  test('새 클립은 임시 파일을 videos/로 옮기고 상대경로로 넘긴다', () async {
    final staged = await stage();
    await service.save(
        formData: form, mode: const CreateMode(), stagedFilePath: staged);

    final (kind, _, path, segments) = provider.calls.single;
    expect(kind, 'add');
    expect(path, startsWith('videos/'));
    expect(File('${root.path}/docs/$path').existsSync(), isTrue);
    expect(File(staged).existsSync(), isFalse);
    expect((segments.single.startMs, segments.single.endMs), (1250, 2500));
  });

  test('영상을 바꾸지 않은 편집은 재생용 절대경로가 아니라 저장돼 있던 경로를 넘긴다',
      () async {
    await service.save(
      formData: form,
      mode: const EditMode(clipId: 7, existingFilePath: 'videos/a.mp4'),
      stagedFilePath: '${root.path}/docs/videos/a.mp4',
    );
    expect(provider.calls.single.$1, 'update');
    expect(provider.calls.single.$2, 7);
    expect(provider.calls.single.$3, 'videos/a.mp4');
  });

  test('경로가 빈 Drive 클립 편집은 빈 경로 그대로 넘겨 파일을 만들지 않는다', () async {
    await service.save(
      formData: form,
      mode: const EditMode(clipId: 8, existingFilePath: ''),
      stagedFilePath: '${root.path}/docs/media/cache/r1/clip_8.mp4',
    );
    expect(provider.calls.single.$3, '');
    expect(Directory('${root.path}/docs/videos').listSync(), isEmpty);
  });

  test('편집에서 새 영상을 고르면 새 파일을 videos/로 옮겨 그 경로를 넘긴다', () async {
    final staged = await stage();
    await service.save(
      formData: form,
      mode: const EditMode(clipId: 9, existingFilePath: 'videos/old.mp4'),
      stagedFilePath: staged,
    );
    final path = provider.calls.single.$3;
    expect(path, isNot('videos/old.mp4'));
    expect(path, startsWith('videos/'));
    expect(File('${root.path}/docs/$path').existsSync(), isTrue);
  });
}
