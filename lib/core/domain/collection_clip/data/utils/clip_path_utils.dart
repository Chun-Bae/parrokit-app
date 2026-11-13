// ============================================================================
// lib/core/collection_media/data/utils/clip_path_utils.dart
// ============================================================================
//
// [역할]
// Clip 파일/썸네일 경로 계산을 위한 순수 정적 유틸리티. db, 네트워크 등
// 어떤 서비스에도 의존하지 않습니다.
//
// [레이어]
// Core > Collection Media > Data > Utils
// ============================================================================

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ClipPathUtils {
  ClipPathUtils._();

  /// clip.filePath가 상대경로라면 App Documents와 합쳐 절대경로로 변환.
  /// 절대경로인데 그 파일이 없으면, 예전 앱 폴더 경로로 저장된 것으로 보고
  /// 지금 Documents 아래 같은 자리에서 찾는다([resolveAgainstDocuments]).
  static Future<String> absolutePathFor(String pathFromClip) async {
    if (pathFromClip.startsWith('/') &&
        (documentsRelativePart(pathFromClip) == null ||
            File(pathFromClip).existsSync())) {
      return pathFromClip;
    }
    final dir = await getApplicationDocumentsDirectory();
    return resolveAgainstDocuments(
      pathFromClip,
      dir.path,
      (path) => File(path).existsSync(),
    );
  }

  /// iOS는 앱을 다시 설치하거나 업데이트할 때 앱 폴더 경로(…/Application/{UUID}/)가
  /// 바뀔 수 있다. 예전 편집 저장이 재생용 절대경로를 DB에 남긴 클립이 있어서(5차),
  /// 그 경로에 파일이 없으면 '/Documents/' 뒤 부분을 지금 [documentsDir]에서 찾는다.
  /// 저장된 값은 바꾸지 않고 읽을 때만 고친다.
  static String resolveAgainstDocuments(
    String pathFromClip,
    String documentsDir,
    bool Function(String path) exists,
  ) {
    if (!pathFromClip.startsWith('/')) return '$documentsDir/$pathFromClip';
    if (exists(pathFromClip)) return pathFromClip;
    final relative = documentsRelativePart(pathFromClip);
    if (relative == null) return pathFromClip;
    final moved = '$documentsDir/$relative';
    return exists(moved) ? moved : pathFromClip;
  }

  /// 절대경로에서 앱 Documents 아래 부분('videos/a.mp4')을 뽑는다. 없으면 null.
  static String? documentsRelativePart(String absolutePath) {
    const marker = '/Documents/';
    final index = absolutePath.indexOf(marker);
    if (index < 0) return null;
    final rest = absolutePath.substring(index + marker.length);
    return rest.isEmpty ? null : rest;
  }

  static Future<int> fileSizeFor(String pathFromClip) async {
    try {
      final abs = await absolutePathFor(pathFromClip);
      final f = File(abs);
      if (await f.exists()) {
        return await f.length();
      }
    } catch (_) {}
    return 0;
  }

  static String normalizedVideoExtension(String? extensionHint) {
    final raw = (extensionHint ?? '').trim();
    if (raw.isEmpty) return '.mp4';
    return raw.startsWith('.') ? raw : '.$raw';
  }

  static Future<String> defaultCachePathForClip({
    required int clipId,
    required String remoteDocId,
    String? extensionHint,
  }) async {
    final ext = normalizedVideoExtension(extensionHint);
    return 'media/cache/$remoteDocId/clip_$clipId$ext';
  }

  static Future<String> defaultSourcePathForClip({
    required int clipId,
    required String title,
    required String remoteDocId,
    String? extensionHint,
  }) async {
    final ext = normalizedVideoExtension(extensionHint);
    final safeTitle = title.trim().isEmpty
        ? 'clip_$clipId'
        : title.replaceAll(RegExp(r'[^A-Za-z0-9가-힣._-]+'), '_');
    return 'media/local/${safeTitle}_$remoteDocId$ext';
  }

  static String buildDriveFileName(String absPath) {
    final extension = p.extension(absPath);
    return 'video${extension.isEmpty ? '.mp4' : extension}';
  }

  static String extensionOf(String path) => p.extension(path);
}
