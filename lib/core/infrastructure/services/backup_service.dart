// ============================================================================
// lib/core/services/backup_service.dart
// ============================================================================
//
// [역할]
// 앱 데이터(DB, 미디어 파일)의 백업 및 복원을 담당하는 서비스.
//
// [레이어]
// Core Layer > Services
// ============================================================================

import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'dart:io' show File, Directory, Platform;

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:archive/archive_io.dart';
import 'package:archive/archive.dart' as a;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:restart_app/restart_app.dart';

import 'package:parrokit/features/settings/more/presentation/widgets/backup_progress_dialog.dart'
    show BackupProgress, BackupProgressState;

// ─────────────────────────────────────────────────────────────────────────────
// Isolate 압축용 파라미터
// ─────────────────────────────────────────────────────────────────────────────

/// Isolate에 전달할 압축 작업 파라미터.
///
/// 테스트에서 [BackupService.compressBackup]을 직접 부르려고 공개했다.
class BackupCompressParams {
  final String zipPath;
  final String? dbPath;
  final String dbRelativePath;
  final String mediaPath;
  final List<String> filePaths;
  final String mediaRelativeDir;
  final String timestamp;

  const BackupCompressParams({
    required this.zipPath,
    required this.dbPath,
    required this.dbRelativePath,
    required this.mediaPath,
    required this.filePaths,
    required this.mediaRelativeDir,
    required this.timestamp,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// BackupService
// ─────────────────────────────────────────────────────────────────────────────

/// 백업 및 복원 서비스 (싱글톤).
class BackupService {
  BackupService._internal();

  static final BackupService instance = BackupService._internal();

  // ───────────────────────────────────────────────────────────────────────────
  // Constants
  // ───────────────────────────────────────────────────────────────────────────

  final String dbRelativePath = 'paro.db';
  final String mediaRelativeDir = '';

  // ───────────────────────────────────────────────────────────────────────────
  // Private Helpers
  // ───────────────────────────────────────────────────────────────────────────

  Future<Directory> _appDocDir() async =>
      await getApplicationDocumentsDirectory();

  /// DB 파일 경로 반환 (없으면 생성).
  Future<File> _dbFile() async {
    final dir = await _appDocDir();
    final f = File(p.join(dir.path, dbRelativePath));
    await f.parent.create(recursive: true);
    return f;
  }

  /// Media 디렉터리 경로 반환 (없으면 생성).
  Future<Directory> _mediaDir() async {
    final dir = await _appDocDir();
    final d = Directory(p.join(dir.path, mediaRelativeDir));
    await d.create(recursive: true);
    return d;
  }

  /// 파일의 SHA256 해시 계산 (무결성 검증용).
  Future<String> _sha256OfFile(File f) async {
    if (!await f.exists()) return '';
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Public API: Backup
  // ───────────────────────────────────────────────────────────────────────────

  /// 백업 파일(.zip) 생성.
  ///
  /// 1. 데이터 확인: DB 및 미디어 파일 목록 수집, 용량 계산
  /// 2. 데이터 압축: Isolate에서 zip 파일 생성
  /// 3. 파일 저장: 사용자에게 저장 위치 선택
  Future<File> createBackup({Function(BackupProgress)? onProgress}) async {
    // 1단계: 데이터 확인
    onProgress?.call(BackupProgress(state: BackupProgressState.checking));

    final appDir = await _appDocDir();
    final db = await _dbFile();
    final media = await _mediaDir();
    final ts = DateTime.now();

    // 기존 backup_*.zip 정리
    await for (final ent in appDir.list(recursive: false, followLinks: false)) {
      if (ent is File && p.basename(ent.path).startsWith('backup_')) {
        try {
          await ent.delete();
        } catch (_) {}
      }
    }

    // 파일 목록 구성 및 용량 계산
    int totalBytes = 0;
    final List<String> filePaths = [];

    if (await db.exists()) {
      totalBytes += await db.length();
    }

    if (await media.exists()) {
      await for (final ent in media.list(recursive: true, followLinks: false)) {
        if (ent is! File) continue;
        final base = p.basename(ent.path);
        if (base.startsWith('backup_') || base == 'manifest.json') continue;
        filePaths.add(ent.path);
        totalBytes += await ent.length();
      }
    }

    // 용량 정보와 함께 상태 업데이트
    onProgress?.call(BackupProgress(
      state: BackupProgressState.checking,
      totalBytes: totalBytes,
    ));

    // 2단계: 데이터 압축 (compute()로 별도 스레드에서 실행)
    onProgress?.call(BackupProgress(
      state: BackupProgressState.compressing,
      totalBytes: totalBytes,
    ));

    final name =
        'backup_${ts.year}${pad2(ts.month)}${pad2(ts.day)}_${pad2(ts.hour)}${pad2(ts.minute)}${pad2(ts.second)}.zip';
    final backupZipPath = p.join(appDir.path, name);

    // compute()로 별도 Isolate에서 압축 실행
    await compute(
      compressBackup,
      BackupCompressParams(
        zipPath: backupZipPath,
        dbPath: await db.exists() ? db.path : null,
        dbRelativePath: dbRelativePath,
        mediaPath: media.path,
        filePaths: filePaths,
        mediaRelativeDir: mediaRelativeDir,
        timestamp: ts.toIso8601String(),
      ),
    );

    final backupZip = File(backupZipPath);

    // 3단계: 파일 저장
    onProgress?.call(BackupProgress(state: BackupProgressState.saving));
    final saved = await _save(backupZip, name);

    if (saved) {
      try {
        await backupZip.delete();
      } catch (_) {}
    } else {
      throw Exception('파일 저장이 취소되었거나 실패했습니다.');
    }

    return backupZip;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Isolate Helpers (static)
  // ─────────────────────────────────────────────────────────────────────────────

  /// 별도 Isolate에서 실행되는 압축 로직.
  ///
  /// 전에는 파일을 읽다 실패하면 빈 catch로 넘기고, manifest에는 그 파일이
  /// 들어간 것처럼 적었다. 그래서 이런 일이 생겼다.
  ///
  /// - DB를 못 읽으면 zip에 DB 없이 백업이 "완료"된다. 사용자는 성공했다고
  ///   믿고 원본을 지울 수도 있다.
  /// - manifest는 DB가 있다고 적혀 있으니, 나중에 복원할 때
  ///   `Missing file from archive`로 실패한다. **백업이 쓸모없다는 걸 복원하는
  ///   순간에야 알게 된다.** 보통 그때는 원본이 이미 없다.
  ///
  /// 그래서 DB를 못 읽으면 백업 자체를 실패시킨다. 미디어 파일 하나를 못
  /// 읽는 건 넘어가되, 실제로 담은 것만 manifest에 적는다.
  ///
  /// 파일 선택창 없이 압축만 부를 수 있게 공개했다. 전에는 private static이라
  /// 위 버그에 회귀 테스트를 붙일 수 없었다.
  @visibleForTesting
  static void compressBackup(BackupCompressParams params) {
    final encoder = ZipFileEncoder();
    encoder.create(params.zipPath);

    final entries = <Map<String, dynamic>>[];

    // DB 추가
    if (params.dbPath != null) {
      final dbFile = File(params.dbPath!);
      final Uint8List bytes;
      try {
        bytes = dbFile.readAsBytesSync();
      } catch (e) {
        encoder.closeSync();
        throw StateError('백업할 데이터베이스를 읽지 못했습니다: $e');
      }
      encoder.addArchiveFile(
        a.ArchiveFile(params.dbRelativePath, bytes.length, bytes),
      );
      entries.add({
        'path': params.dbRelativePath,
        'sha256': sha256.convert(bytes).toString(),
        'bytes': bytes.length,
      });
    }

    // Media 추가
    for (final filePath in params.filePaths) {
      if (filePath == params.dbPath) continue;
      final file = File(filePath);

      try {
        final rel =
            p.relative(filePath, from: params.mediaPath).replaceAll('\\', '/');
        final inZip =
            p.join(params.mediaRelativeDir, rel).replaceAll('\\', '/');

        if (!file.existsSync()) continue;

        // 대용량 파일일 수 있지만, 확실한 저장을 위해 바이트로 읽음
        final bytes = file.readAsBytesSync();
        encoder.addArchiveFile(a.ArchiveFile(inZip, bytes.length, bytes));

        // 실제로 담은 것만 적는다. 전에는 담기 실패한 파일도 manifest에
        // 들어가서 복원이 "Missing file from archive"로 넘어졌다.
        entries.add({
          'path': inZip,
          'sha256': sha256.convert(bytes).toString(),
          'bytes': bytes.length,
        });
      } catch (_) {
        // 미디어 파일 하나를 못 읽어도 나머지는 백업한다. manifest에 안 적으니
        // 복원할 때 없는 파일을 찾지 않는다.
        continue;
      }
    }

    final manifest = {
      'createdAt': params.timestamp,
      'db': params.dbRelativePath,
      'mediaDir': params.mediaRelativeDir,
      'entries': entries,
      'version': 1,
    };

    final manifestBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));

    encoder.addArchiveFile(
        a.ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    encoder.close();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // File Save Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// 플랫폼별 파일 저장 다이얼로그 호출.
  Future<bool> _save(File backupZip, String suggestedName) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final params = SaveFileDialogParams(
          sourceFilePath: backupZip.path,
          fileName: suggestedName,
        );
        final savedPath = await FlutterFileDialog.saveFile(params: params);
        return savedPath != null;
      } else {
        final bytes = await backupZip.readAsBytes();
        await FileSaver.instance.saveFile(
          name: suggestedName,
          bytes: bytes,
          mimeType: MimeType.zip,
        );
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Public API: Restore
  // ─────────────────────────────────────────────────────────────────────────────

  /// 백업 파일(.zip)에서 데이터 복원.
  ///
  /// 1. 파일 분석: zip 파일 선택 및 manifest 확인
  /// 2. 압축 해제: 임시 디렉터리에 파일 추출
  /// 3. 데이터 복원: 파일 무결성 검증 후 이동, 앱 재시작
  Future<void> restoreBackup({Function(BackupProgress)? onProgress}) async {
    // 1단계: 파일 분석
    onProgress?.call(BackupProgress(state: BackupProgressState.analyzing));

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (res == null || res.files.isEmpty) {
      throw Exception('파일 선택이 취소되었습니다.');
    }

    final appDir = await _appDocDir();
    final zipPath = res.files.single.path!;
    final ts = DateTime.now().millisecondsSinceEpoch;

    // 이전 임시 폴더 정리
    try {
      await for (final ent
          in appDir.list(recursive: false, followLinks: false)) {
        if (ent is Directory &&
            p.basename(ent.path).startsWith('.restore_tmp_')) {
          try {
            await ent.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}

    final tmpDir = Directory(p.join(appDir.path, '.restore_tmp_$ts'));
    await tmpDir.create(recursive: true);

    Archive archive;
    try {
      final inputStream = InputFileStream(zipPath);
      archive = ZipDecoder().decodeStream(inputStream);
      await inputStream.close();
    } catch (e) {
      try {
        await _deleteDir(tmpDir);
      } catch (_) {}
      rethrow;
    }

    // 2단계: 압축 해제
    onProgress?.call(BackupProgress(state: BackupProgressState.extracting));

    try {
      for (final file in archive) {
        await Future.delayed(const Duration(milliseconds: 1)); // UI 양보

        // 경로 구분자 정규화 (백슬래시 → 슬래시)
        final normalizedName = file.name.replaceAll('\\', '/');
        final outPath = p.join(tmpDir.path, normalizedName);

        if (file.isFile) {
          await File(outPath).parent.create(recursive: true);
          final out = OutputFileStream(outPath);
          file.writeContent(out);
          await out.close();
        } else {
          try {
            await Directory(outPath).create(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      try {
        await _deleteDir(tmpDir);
      } catch (_) {}
      rethrow;
    }

    // manifest.json 로드
    Future<File?> findManifestIn(Directory root) async {
      final exact = File(p.join(root.path, 'manifest.json'));
      if (await exact.exists()) return exact;
      await for (final ent in root.list(recursive: true, followLinks: false)) {
        if (ent is File &&
            p.basename(ent.path).trim().toLowerCase() == 'manifest.json') {
          return ent;
        }
      }
      return null;
    }

    final tmpManifest = await findManifestIn(tmpDir);
    if (tmpManifest == null) {
      try {
        await _deleteDir(tmpDir);
      } catch (_) {}
      throw StateError('Backup manifest.json not found in archive.');
    }

    Map<String, dynamic> manifestMap;
    try {
      manifestMap =
          jsonDecode(await tmpManifest.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      try {
        await _deleteDir(tmpDir);
      } catch (_) {}
      throw StateError('Invalid manifest.json.');
    }

    // manifest가 위치한 디렉토리를 기준으로 파일 찾기
    final manifestDir = tmpManifest.parent;

    // 엔트리 검증
    final List entries = manifestMap['entries'] ?? [];
    for (final e in entries) {
      final rel = (e['path'] as String?) ?? '';
      if (rel.isEmpty || p.isAbsolute(rel) || rel.contains('..')) {
        try {
          await _deleteDir(tmpDir);
        } catch (_) {}
        throw StateError('Unsafe path in manifest: $rel');
      }
      // manifest 디렉토리 기준으로 파일 찾기
      final tmpFile = File(p.join(manifestDir.path, rel));
      if (!await tmpFile.exists()) {
        try {
          await _deleteDir(tmpDir);
        } catch (_) {}
        throw StateError('Missing file from archive: $rel');
      }
      final expectedSha = (e['sha256'] as String?) ?? '';
      if (expectedSha.isNotEmpty) {
        final sha = await _sha256OfFile(tmpFile);
        if (sha != expectedSha) {
          try {
            await _deleteDir(tmpDir);
          } catch (_) {}
          throw StateError('Hash mismatch for $rel');
        }
      }
    }

    // 현재 DB 백업
    try {
      final dbFile = await _dbFile();
      if (await dbFile.exists()) {
        final bakPath = '${dbFile.path}.bak_$ts';
        await dbFile.copy(bakPath);
      }
    } catch (_) {
      try {
        await _deleteDir(tmpDir);
      } catch (_) {}
      rethrow;
    }

    // 3단계: 데이터 복원
    onProgress?.call(BackupProgress(state: BackupProgressState.restoring));

    try {
      for (final e in entries) {
        if (entries.indexOf(e) % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 1));
        }

        final rel = e['path'] as String;
        // manifest 디렉토리 기준으로 소스 파일 찾기
        final src = File(p.join(manifestDir.path, rel));
        final dst = File(p.join(appDir.path, rel));

        if (!await src.exists()) continue;

        await dst.parent.create(recursive: true);
        try {
          await src.rename(dst.path);
        } catch (_) {
          await src.copy(dst.path);
          try {
            await src.delete();
          } catch (_) {}
        }
      }

      // manifest.json 이동
      final dstManifest = File(p.join(appDir.path, 'manifest.json'));
      await dstManifest.parent.create(recursive: true);
      try {
        await tmpManifest.rename(dstManifest.path);
      } catch (_) {
        await tmpManifest.copy(dstManifest.path);
        try {
          await tmpManifest.delete();
        } catch (_) {}
      }

      // paro.db 보장
      final dbRel = dbRelativePath;
      final dbSrc = File(p.join(tmpDir.path, dbRel));
      final dbDst = File(p.join(appDir.path, dbRel));
      if (!await dbSrc.exists()) {
        ArchiveFile? dbEntry;
        for (final f in archive.files) {
          if (f.isFile && f.name.replaceAll('\\', '/') == dbRel) {
            dbEntry = f;
            break;
          }
        }
        if (dbEntry != null) {
          await dbDst.parent.create(recursive: true);
          final out = OutputFileStream(dbDst.path);
          dbEntry.writeContent(out);
          await out.close();
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      try {
        await _deleteDir(tmpDir);
      } catch (_) {}
      Restart.restartApp();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Utilities
  // ───────────────────────────────────────────────────────────────────────────

  /// 디렉터리 삭제 (존재 시).
  Future<void> _deleteDir(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 숫자를 2자리 문자열로 패딩.
  String pad2(int n) => n.toString().padLeft(2, '0');
}
