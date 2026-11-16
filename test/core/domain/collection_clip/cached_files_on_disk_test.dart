// 받아 둔 파일이 아직 기기에 남아 있는지 가리는 규칙(5차 363).
//
// 더보기의 '받아 둔 영상 N개 · N MB'와 '받아 둔 영상' 목록이 서로 다른 규칙을
// 써서, 파일이 사라진 뒤에도 더보기에는 숫자가 남고 목록은 비어 있었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/cached_files_on_disk.dart';

void main() {
  const entries = [
    (id: 1, path: 'clips/a.mp4'),
    (id: 2, path: 'clips/gone.mp4'),
    (id: 3, path: 'clips/empty.mp4'),
    (id: 4, path: '   '),
  ];

  Future<int> fakeSize(String path) async => switch (path) {
        'clips/a.mp4' => 1024,
        'clips/empty.mp4' => 0,
        _ => 0,
      };

  test('파일이 남아 있는 줄만 남긴다', () async {
    final kept = await keepFilesStillOnDisk(entries,
        filePathOf: (e) => e.path, sizeOf: fakeSize);
    expect(kept.map((e) => e.id), [1]);
  });

  test('빈 목록은 빈 목록', () async {
    final kept = await keepFilesStillOnDisk<({int id, String path})>([],
        filePathOf: (e) => e.path, sizeOf: fakeSize);
    expect(kept, isEmpty);
  });

  test('없는 파일은 크기 0으로 본다', () async {
    final missing = '${Directory.systemTemp.path}/parrokit-not-here-363.mp4';
    expect(await cachedFileSizeOnDisk(missing), 0);
  });

  test('개수·용량을 세는 쪽과 목록을 만드는 쪽이 같은 규칙을 쓴다', () {
    final counter = File(
            'lib/core/domain/collection_clip/data/datasources/clip_source_ref_datasource.dart')
        .readAsStringSync();
    final list = File(
            'lib/core/domain/collection_clip/data/datasources/clip_item_query_datasource.dart')
        .readAsStringSync();
    expect(counter, contains('keepFilesStillOnDisk'));
    expect(list, contains('keepFilesStillOnDisk'));
  });

  test('크기 표시는 한 함수에서만 만든다', () {
    for (final path in [
      'lib/features/settings/more/presentation/sections/data_section.dart',
      'lib/features/settings/more/presentation/sections/remote_storage_section.dart',
      'lib/features/settings/more/presentation/storage_cache_management_screen.dart',
    ]) {
      final code = File(path).readAsStringSync();
      expect(code.contains("const units = ['B', 'KB', 'MB', 'GB']"), isFalse,
          reason: '$path에 크기 계산이 또 복사돼 있다');
      expect(code, contains('utils/format_bytes.dart'));
    }
  });
}
