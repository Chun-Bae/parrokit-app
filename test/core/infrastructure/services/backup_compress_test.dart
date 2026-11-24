// 백업 압축의 회귀 테스트.
//
// 전에는 데이터베이스를 읽다 실패해도 빈 catch로 넘어가서, zip에 DB 없이
// 백업이 "완료"됐다. manifest에는 DB가 있다고 적혀 있어서 복원하는 순간에야
// "Missing file from archive"로 실패했다. 지금은 DB를 못 읽으면 백업 자체가
// 실패하고, 미디어 파일은 실제로 담은 것만 manifest에 적는다.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/progress_transfer.dart';
import 'package:parrokit/core/content/study_data_transfer.dart';
import 'package:parrokit/core/infrastructure/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory media;
  late File db;

  setUp(() {
    root = Directory.systemTemp.createTempSync('backup_compress_test');
    media = Directory(p.join(root.path, 'media'))..createSync();
    db = File(p.join(root.path, 'app.sqlite'))..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() {
    // 읽기 막아 둔 파일이 남아 있으면 지우기 전에 풀어 준다.
    for (final f in media.listSync(recursive: true).whereType<File>()) {
      Process.runSync('chmod', ['644', f.path]);
    }
    root.deleteSync(recursive: true);
  });

  BackupCompressParams paramsFor({
    String? dbPath,
    required List<String> files,
    String? studyJson,
    String? progressJson,
    String? mediaPath,
    String mediaRelativeDir = 'media',
    List<String> parts = const ['clips'],
  }) =>
      BackupCompressParams(
        zipPath: p.join(root.path, 'out.zip'),
        dbPath: dbPath,
        dbRelativePath: 'db/app.sqlite',
        mediaPath: mediaPath ?? media.path,
        filePaths: files,
        mediaRelativeDir: mediaRelativeDir,
        timestamp: '2026-11-12T00:00:00.000',
        studyJson: studyJson,
        progressJson: progressJson,
        parts: parts,
      );

  Map<String, dynamic> manifestOf(Archive zip) => jsonDecode(
        utf8.decode(zip.findFile('manifest.json')!.content as List<int>),
      ) as Map<String, dynamic>;

  Archive readZip() => ZipDecoder()
      .decodeBytes(File(p.join(root.path, 'out.zip')).readAsBytesSync());

  List<String> manifestPaths(Archive zip) {
    final manifest = jsonDecode(
      utf8.decode(zip.findFile('manifest.json')!.content as List<int>),
    ) as Map<String, dynamic>;
    return (manifest['entries'] as List)
        .map((e) => (e as Map<String, dynamic>)['path'] as String)
        .toList();
  }

  test('DB와 미디어를 담고 manifest에 둘 다 적는다', () {
    final clip = File(p.join(media.path, 'clip.mp4'))..writeAsBytesSync([9, 9]);

    BackupService.compressBackup(
        paramsFor(dbPath: db.path, files: [clip.path]));

    final zip = readZip();
    expect(zip.findFile('db/app.sqlite'), isNotNull);
    expect(zip.findFile('media/clip.mp4'), isNotNull);
    expect(manifestPaths(zip), ['db/app.sqlite', 'media/clip.mp4']);
  });

  test('DB를 읽지 못하면 DB 없는 백업을 만들지 않고 실패한다', () {
    // 경로에 파일 대신 디렉터리를 두면 readAsBytesSync가 실패한다.
    final unreadableDb = Directory(p.join(root.path, 'not-a-file'))
      ..createSync();

    expect(
      () => BackupService.compressBackup(
        paramsFor(dbPath: unreadableDb.path, files: const []),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('읽지 못한 미디어 파일은 manifest에 적지 않는다', () {
    final ok = File(p.join(media.path, 'ok.mp4'))..writeAsBytesSync([1]);
    final locked = File(p.join(media.path, 'locked.mp4'))
      ..writeAsBytesSync([2]);
    Process.runSync('chmod', ['000', locked.path]);

    BackupService.compressBackup(
      paramsFor(dbPath: db.path, files: [ok.path, locked.path]),
    );

    final zip = readZip();
    expect(manifestPaths(zip), ['db/app.sqlite', 'media/ok.mp4']);
    expect(zip.findFile('media/locked.mp4'), isNull);
  });

  group('문장·단어 담기(5차 345)', () {
    test('study.json을 담고 manifest에 적는다', () {
      BackupService.compressBackup(paramsFor(
        dbPath: db.path,
        files: const [],
        studyJson: '{"version":1,"sentences":[],"words":[]}',
        parts: const ['clips', 'sentences', 'words'],
      ));

      final zip = readZip();
      expect(zip.findFile(studyDataFileName), isNotNull);
      expect(manifestPaths(zip), contains(studyDataFileName));
      expect(manifestOf(zip)['parts'], ['clips', 'sentences', 'words']);
    });

    test('클립 없이 문장만 담으면 DB는 들어가지 않는다', () {
      BackupService.compressBackup(paramsFor(
        dbPath: null,
        files: const [],
        studyJson: '{"version":1,"sentences":[],"words":[]}',
        parts: const ['sentences'],
      ));

      final zip = readZip();
      expect(zip.findFile('db/app.sqlite'), isNull);
      expect(zip.findFile(studyDataFileName), isNotNull);
      expect(manifestOf(zip)['parts'], ['sentences']);
    });

    test('예전처럼 클립만 담으면 study.json도 parts도 예전 그대로다', () {
      BackupService.compressBackup(paramsFor(dbPath: db.path, files: const []));

      final zip = readZip();
      expect(zip.findFile(studyDataFileName), isNull);
      expect(manifestOf(zip)['parts'], ['clips']);
      expect(manifestPaths(zip), ['db/app.sqlite']);
    });
  });

  // 되돌리기가 앱 폴더에 progress.json을 남겨 뒀고, 다음 백업이 앱 폴더를
  // 훑으면서 그 묵은 파일까지 담았다(5차). zip 안에 같은 이름이 둘 들어가고
  // manifest에도 sha256이 서로 다른 줄이 둘 적혀, 방금 만든 백업을 그 자리에서
  // 불러오면 'Hash mismatch for progress.json'으로 통째로 막혔다.
  test('앱 폴더에 남은 묵은 progress.json이 새것과 함께 담기지 않는다', () {
    const fresh = '{"version":1,"sentences":[],"words":[]}';
    final stale = File(p.join(root.path, progressDataFileName))
      ..writeAsStringSync('{"version":1,"sentences":[{"id":1}],"words":[]}');

    BackupService.compressBackup(paramsFor(
      dbPath: db.path,
      files: [stale.path],
      progressJson: fresh,
      studyJson: '{"version":1,"sentences":[],"words":[]}',
      mediaPath: root.path,
      mediaRelativeDir: '',
      parts: const ['clips', 'sentences', 'words'],
    ));

    final zip = readZip();
    final paths = manifestPaths(zip);
    expect(paths.where((e) => e == progressDataFileName).length, 1);
    expect(
      zip.files.where((f) => f.name == progressDataFileName).length,
      1,
    );
    // 담긴 것은 지금 값이어야 한다. 묵은 쪽이 이기면 되돌릴 때 예전 진도가
    // 덮어쓴다.
    expect(
      utf8.decode(zip.findFile(progressDataFileName)!.content as List<int>),
      fresh,
    );
  });

  // manifest의 sha256은 zip에 실제로 담긴 내용과 맞아야 한다. 하나라도
  // 어긋나면 되돌리기가 'Hash mismatch'로 전부 막힌다.
  test('manifest의 sha256이 zip 안 내용과 모두 맞는다', () {
    final stale = File(p.join(root.path, progressDataFileName))
      ..writeAsStringSync('{"version":1,"sentences":[{"id":1}],"words":[]}');

    BackupService.compressBackup(paramsFor(
      dbPath: db.path,
      files: [stale.path],
      progressJson: '{"version":1,"sentences":[],"words":[]}',
      mediaPath: root.path,
      mediaRelativeDir: '',
      parts: const ['clips', 'sentences', 'words'],
    ));

    final zip = readZip();
    final entries = (manifestOf(zip)['entries'] as List)
        .cast<Map<String, dynamic>>();
    for (final e in entries) {
      final file = zip.findFile(e['path'] as String);
      expect(file, isNotNull, reason: '${e['path']} 가 zip에 없다');
      expect(
        sha256.convert(file!.content as List<int>).toString(),
        e['sha256'],
        reason: '${e['path']} 의 sha256이 어긋난다',
      );
    }
  });
}
