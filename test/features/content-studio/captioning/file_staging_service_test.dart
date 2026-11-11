import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/data/services/file_staging_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// 테스트가 진짜 기기 경로를 쓰지 않도록 임시 폴더를 돌려주는 가짜 구현.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getTemporaryPath() async => '${root.path}/tmp';

  @override
  Future<String?> getApplicationDocumentsPath() async => '${root.path}/docs';
}

void main() {
  late Directory root;
  late FileStagingService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('staging_test');
    await Directory('${root.path}/tmp').create(recursive: true);
    await Directory('${root.path}/docs').create(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(root);
    service = FileStagingService();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> writeStagedFile(List<int> bytes) async {
    final source = File('${root.path}/source.mp4');
    await source.writeAsBytes(bytes);
    return service.stageFromPath(source.path);
  }

  test('finalize는 내용을 그대로 옮기고 임시 파일을 지운다', () async {
    final bytes = List<int>.generate(2048, (i) => i % 256);
    final staged = await writeStagedFile(bytes);

    final relative = await service.finalize(staged);

    expect(relative, startsWith('videos/'));
    final saved = File('${root.path}/docs/$relative');
    expect(await saved.exists(), isTrue);
    expect(await saved.readAsBytes(), bytes);
    expect(await File(staged).exists(), isFalse);
  });

  // 이 실패 경로에서는 고치기 전에도 videos/ 아래에 파일이 생기지 않았다.
  // 그래서 이 테스트가 그 버그를 잡아낸 건 아니고, 실패하면 아무것도 남지
  // 않는다는 성질을 앞으로 깨뜨리지 않게 잡아 두는 쪽이다.
  test('원본이 사라졌으면 던지고 videos/ 아래에 아무것도 남기지 않는다', () async {
    final staged = await writeStagedFile(List<int>.filled(1024, 7));
    await File(staged).delete();

    await expectLater(service.finalize(staged), throwsA(isA<Exception>()));

    final videosDir = Directory('${root.path}/docs/videos');
    final leftovers = await videosDir.exists()
        ? await videosDir.list().toList()
        : <FileSystemEntity>[];
    expect(leftovers, isEmpty, reason: '실패하면 videos/ 아래에 아무것도 남으면 안 된다');
  });

  test('discard는 파일이 없어도 던지지 않는다', () async {
    await service.discard('${root.path}/없는파일.mp4');
  });

  test('isInStaging은 임시 폴더 경로만 참으로 본다', () async {
    final staged = await writeStagedFile(List<int>.filled(16, 1));
    expect(service.isInStaging(staged), isTrue);
    expect(service.isInStaging('${root.path}/docs/videos/a.mp4'), isFalse);
  });

  test('sweepOld는 오래된 임시 파일만 지운다', () async {
    final fresh = await writeStagedFile(List<int>.filled(16, 1));
    final old = await writeStagedFile(List<int>.filled(16, 2));
    await File(old)
        .setLastModified(DateTime.now().subtract(const Duration(hours: 72)));

    await service.sweepOld();

    expect(await File(fresh).exists(), isTrue);
    expect(await File(old).exists(), isFalse);
  });
}
