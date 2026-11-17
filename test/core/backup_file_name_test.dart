// 백업 파일 이름에 Parrokit을 넣는다(사용자 요청 2026-11-17).
//
// 전에는 'backup_20261117_124400.zip'이라 다른 앱 백업과 섞이면 어느 것이
// Parrokit 것인지 알 수 없었다. 이름만 바꾸고 예전 이름을 못 알아보면
// 앱 폴더에 남은 예전 백업을 지우지도 빼지도 못해, 새 백업 안에 예전
// 백업이 통째로 들어간다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/backup_file_name.dart';

void main() {
  test('이름에 Parrokit과 날짜·시각이 들어간다', () {
    final name = backupFileName(DateTime(2026, 11, 17, 12, 44, 5));
    expect(name, 'Parrokit_백업_20261117_124405.zip');
  });

  test('음성 파일 이름과 같은 꼴이다', () {
    final name = backupFileName(DateTime(2026, 1, 2, 3, 4, 5));
    expect(name, startsWith('Parrokit_'));
    expect(name, contains('20260102_030405'));
  });

  test('예전 이름도 백업 찌꺼기로 알아본다', () {
    expect(isBackupFileName('Parrokit_백업_20261117_124405.zip'), isTrue);
    expect(isBackupFileName('backup_20261101_010101.zip'), isTrue);
    expect(isBackupFileName('paro.db'), isFalse);
    expect(isBackupFileName('manifest.json'), isFalse);
  });

  test('백업 서비스가 이 이름만 쓴다', () {
    final code = File('lib/core/infrastructure/services/backup_service.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code, contains('backupFileName(ts)'));
    expect(code, contains('isBackupFileName('));
    expect(code, isNot(contains("startsWith('backup_')")));
  });
}
