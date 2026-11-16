// 되돌리기(복원)가 중간에 멈췄을 때(5차 387).
//
// 전에는 파일을 옮기다 실패해도 finally에서 앱을 다시 켰다. 반쯤 섞인
// 자료로 돌아오고, 화면은 까닭을 보여 줄 틈도 없었다. 복원 전에 떠 둔
// paro.db 사본도 쓰이지 않고 그대로 쌓였다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final code =
      File('lib/core/infrastructure/services/backup_service.dart')
          .readAsStringSync();

  test('다 끝났을 때만 앱을 다시 켠다', () {
    expect(code, contains('if (restored) {'));
    // 예전처럼 finally에서 조건 없이 다시 켜면 안 된다.
    expect(
        RegExp(r'finally \{\s*try \{\s*await _deleteDir\(tmpDir\);\s*\} catch \(_\) \{\}\s*Restart\.restartApp\(\);')
            .hasMatch(code),
        isFalse);
  });

  test('멈추면 떠 둔 paro.db로 되돌린다', () {
    expect(code, contains('dbBackupPath'));
    expect(code, contains('await bak.copy(dbFileNow.path)'));
  });

  test('잘 끝나면 떠 둔 사본을 치운다', () {
    expect(code, contains('await File(dbBackupPath).delete()'));
  });
}
