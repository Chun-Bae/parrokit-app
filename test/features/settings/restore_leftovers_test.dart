// 되돌리기가 남긴 찌꺼기 치우기(5차 388).
//
// 387 전까지 되돌릴 때마다 paro.db 사본(paro.db.bak_*)이 쌓였다. DB 하나가
// 수십 MB라 기기 용량을 갉아먹는다. 임시 폴더와 함께 치운다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/backup_service.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('parrokit-leftovers');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('임시 폴더와 예전 DB 사본만 치운다', () async {
    final keepDb = File('${root.path}/paro.db')..writeAsStringSync('db');
    final keepVideo = Directory('${root.path}/videos')..createSync();
    final oldCopy = File('${root.path}/paro.db.bak_1700000000000')
      ..writeAsStringSync('old');
    final tempDir = Directory('${root.path}/.restore_tmp_1700000000000')
      ..createSync();
    final keepManifest = File('${root.path}/manifest.json')
      ..writeAsStringSync('{}');

    await BackupService.instance.cleanRestoreLeftovers(root);

    expect(keepDb.existsSync(), isTrue, reason: '지금 쓰는 DB는 그대로');
    expect(keepVideo.existsSync(), isTrue);
    expect(keepManifest.existsSync(), isTrue);
    expect(oldCopy.existsSync(), isFalse);
    expect(tempDir.existsSync(), isFalse);
  });

  test('치울 것이 없어도 그냥 넘어간다', () async {
    await BackupService.instance.cleanRestoreLeftovers(root);
    expect(root.listSync(), isEmpty);
  });

  test('되돌리기를 시작할 때 치운다', () {
    final code = File('lib/core/infrastructure/services/backup_service.dart')
        .readAsStringSync();
    final clean = code.indexOf('await cleanRestoreLeftovers(appDir);');
    final extract = code.indexOf('BackupProgressState.extracting');
    expect(clean, greaterThan(0));
    expect(clean, lessThan(extract));
  });
}
