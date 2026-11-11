// ============================================================================
// lib/features/_content/editor/data/services/file_staging_service.dart
// ============================================================================
//
// [역할]
// 비디오 파일 스테이징 서비스.
// 임시 저장, 최종 저장, 오래된 파일 정리 기능.
//
// [레이어]
// Data Layer > Services
// ============================================================================

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileStagingService {
  final String _stagingDirName;
  final _uuid = const Uuid();

  FileStagingService({String stagingDirName = 'video_staging'})
      : _stagingDirName = stagingDirName;

  /// 업로드 시 임시 동영상 저장 경로
  Future<Directory> _ensureStagingDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/$_stagingDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 최종 저장 경로
  Future<Directory> _ensureFinalDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/videos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 확장자 반환 (".mp4")
  String _extensionOf(String path) {
    if (path.contains('.')) {
      // '.'의 인덱스 위치로 부분 문자열을 가져옴.
      return path.substring(path.lastIndexOf('.'));
    } else {
      return '.mp4';
    }
  }

  /// 확장자를 반환하는데 추천 값(suggested)을 먼저한 후 반환
  String _guessExt(String path, String? suggested) {
    String pick(String s) {
      if (s.contains('.')) {
        return s.substring(s.lastIndexOf('.'));
      } else {
        return '';
      }
    }

    final fromSug = suggested != null ? pick(suggested) : '';
    final fromPath = pick(path);
    return (fromSug.isNotEmpty
        ? fromSug
        : fromPath.isNotEmpty
            ? fromPath
            : '.mp4');
  }

  /// 파일을 바이트 단위로 쓰기
  Future<void> _copyByStream(Stream<List<int>> input, File dest) async {
    final sink = dest.openWrite();
    try {
      await input.pipe(sink);
    } finally {
      await sink.close();
    }
  }

  /// 목적지 경로에 파일 저장
  Future<String> stageFromPath(String srcPath, {String? suggestedName}) async {
    final dir = await _ensureStagingDir();
    final ext = _guessExt(srcPath, suggestedName);
    final name = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}$ext';
    final dest = File('${dir.path}/$name');
    await _copyByStream(File(srcPath).openRead(), dest);
    return dest.path;
  }

  Future<void> discard(String stagedPath) async {
    await _deleteQuietly(File(stagedPath));
  }

  /// 최종 저장
  ///
  /// 복사가 중간에 끊기면 반쯤 쓰인 파일을 지우고 던진다. 전에는 그냥 던져서
  /// 깨진 영상이 videos/ 아래에 남았고, sweepOld는 임시 폴더만 쓸기 때문에
  /// 아무도 치우지 않았다. 저장 용량에는 계속 잡힌다.
  ///
  /// 다 쓴 뒤 길이도 원본과 맞는지 본다. 전에는 `length > 0`만 봐서 잘린
  /// 파일도 통과했고, 그대로 임시 원본을 지워서 되돌릴 수가 없었다.
  Future<String> finalize(String stagedPath) async {
    final finalDir = await _ensureFinalDir();
    final ext = _extensionOf(stagedPath);
    final name = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}$ext';
    final dest = File('${finalDir.path}/$name');

    final sourceLength = await File(stagedPath).length();

    try {
      await _copyByStream(File(stagedPath).openRead(), dest);
    } catch (_) {
      await _deleteQuietly(dest);
      rethrow;
    }

    if (await dest.exists() && await dest.length() == sourceLength) {
      await _deleteQuietly(File(stagedPath));
      return 'videos/$name'; // 상대 경로
    }

    await _deleteQuietly(dest);
    throw Exception('Final copy failed');
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 임시 저장 파일이 있는가?
  bool isInStaging(String path) {
    return path.contains('/$_stagingDirName/');
  }

  /// 오래된 임시 저장한 파일 지우기
  /// - 48시간 이상 지난 파일은 정리한다.
  Future<void> sweepOld({Duration ttl = const Duration(hours: 48)}) async {
    final dir = await _ensureStagingDir();
    if (!await dir.exists()) return;
    final now = DateTime.now();

    await for (final e in dir.list()) {
      if (e is File) {
        final stat = await e.stat();
        if (now.difference(stat.modified) > ttl) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    }
  }
}
