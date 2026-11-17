// Google Drive 연동 해제를 묻는 말과 알림을 한 곳에서만 적는다(5차 422).
//
// 같은 확인 창과 알림이 두 화면에 마흔 줄씩 통째로 복사돼 있었다.
// 한쪽만 고치면 말이 갈린다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shared/drive_disconnect.dart';

const _home = 'lib/features/collection/shared/drive_disconnect.dart';

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

List<String> _uiLines(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .toList();

void main() {
  test('묻는 말과 알림을 다른 파일이 손으로 적지 않는다', () {
    const texts = [
      driveDisconnectTitle,
      driveDisconnectBody,
      driveDisconnectedMessage,
      driveDisconnectFailedMessage,
    ];
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      if (file.path.endsWith(_home)) continue;
      for (final line in _uiLines(file)) {
        for (final text in texts) {
          if (line.contains("'$text'")) offenders.add('${file.path}: $text');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '$_home에서 꺼내 쓴다\n${offenders.join('\n')}');
  });

  test('두 화면이 같은 함수를 부른다', () {
    const callers = [
      'lib/features/settings/more/presentation/sections/remote_storage_section.dart',
      'lib/features/collection/library/presentation/sections/library_folder_section.dart',
    ];
    for (final path in callers) {
      final code = File(path).readAsStringSync();
      expect(code, contains('confirmAndDisconnectGoogleDrive(context)'),
          reason: path);
      // 확인 창을 또 손으로 그리지 않는다.
      expect(code, isNot(contains('disconnectGoogleDrive()')), reason: path);
    }
  });

  test('묻는 말이 무엇이 일어나는지 적는다', () {
    expect(driveDisconnectBody, contains('이 기기로 옮긴 뒤'));
    expect(driveDisconnectConfirmLabel, '연동 해제');
    expect(driveDisconnectCancelLabel, '취소');
  });
}
