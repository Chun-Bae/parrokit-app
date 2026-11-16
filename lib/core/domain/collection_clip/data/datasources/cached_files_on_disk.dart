// 받아 둔(캐시) 파일이 아직 기기에 남아 있는지 가리는 규칙 한 곳(5차 363).
//
// 전에는 이 규칙이 두 곳에 따로 있었다. '받아 둔 영상' 목록은 파일이 실제로
// 있는 것만 보여 줬는데, 더보기의 '받아 둔 영상 N개 · N MB'는 DB의 캐시 줄만
// 세었다. 그래서 파일이 사라진 뒤에도 더보기에는 숫자가 남고, 화면에는
// '아직 없어요'가 떠서 지울 길이 없어 보였다.

import 'dart:io';

import 'package:parrokit/core/domain/collection_clip/data/utils/clip_path_utils.dart';

/// 상대 경로를 받아 파일 크기를 돌려준다. 없으면 0.
typedef CachedFileSize = Future<int> Function(String relativePath);

/// 기본 규칙: 앱 폴더 기준 절대 경로로 바꿔 크기를 잰다.
Future<int> cachedFileSizeOnDisk(String relativePath) async {
  try {
    final file = File(await ClipPathUtils.absolutePathFor(relativePath));
    if (!await file.exists()) return 0;
    return await file.length();
  } catch (_) {
    return 0;
  }
}

/// [entries] 가운데 파일이 실제로 남아 있는(크기가 0보다 큰) 것만 돌려준다.
Future<List<T>> keepFilesStillOnDisk<T>(
  Iterable<T> entries, {
  required String Function(T entry) filePathOf,
  CachedFileSize sizeOf = cachedFileSizeOnDisk,
}) async {
  final kept = <T>[];
  for (final entry in entries) {
    final path = filePathOf(entry).trim();
    if (path.isEmpty) continue;
    if (await sizeOf(path) > 0) kept.add(entry);
  }
  return kept;
}
