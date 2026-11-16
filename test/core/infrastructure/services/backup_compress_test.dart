// 백업 압축의 회귀 테스트.
//
// 전에는 데이터베이스를 읽다 실패해도 빈 catch로 넘어가서, zip에 DB 없이
// 백업이 "완료"됐다. manifest에는 DB가 있다고 적혀 있어서 복원하는 순간에야
// "Missing file from archive"로 실패했다. 지금은 DB를 못 읽으면 백업 자체가
// 실패하고, 미디어 파일은 실제로 담은 것만 manifest에 적는다.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
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
    List<String> parts = const ['clips'],
  }) =>
      BackupCompressParams(
        zipPath: p.join(root.path, 'out.zip'),
        dbPath: dbPath,
        dbRelativePath: 'db/app.sqlite',
        mediaPath: media.path,
        filePaths: files,
        mediaRelativeDir: 'media',
        timestamp: '2026-11-12T00:00:00.000',
        studyJson: studyJson,
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
}
