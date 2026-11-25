// 고른 것이 백업 파일에 없을 때(5차).
//
// 클립만 고르고 문장·단어만 담긴 백업을 고르면 되돌릴 것이 하나도 없다.
// 그런데도 화면은 '다 됐어요 / 다 불러왔어요.'를 띄웠다. 시뮬레이터에서
// 10 KB짜리 문장·단어 백업에 클립만 골라 보고 찾았다. 되찾는 자리에서
// 거짓말을 하면 사용자가 제대로 된 백업 파일을 지운다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/study_data_transfer.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/backup_progress_dialog.dart';

void main() {
  test('하나도 못 불러오면 거기서 멈춘다', () {
    final code =
        File('lib/core/infrastructure/services/backup_service.dart')
            .readAsStringSync();
    final body = code.substring(code.indexOf('final restoring ='));
    final guard = body.indexOf('if (restoring.isEmpty)');
    expect(guard, greaterThan(-1), reason: '빈 것을 먼저 막는다');
    expect(body, contains('throw Exception(backupNothingRestoredMessage)'));
    // 문장·단어를 읽기 전에 막아야 한다. 뒤에 두면 이미 끝까지 간 것이다.
    expect(guard, lessThan(body.indexOf('importStudyData')),
        reason: '되돌리기를 시작하기 전에 막는다');
    // 막을 때도 임시 폴더는 치운다. 다른 실패 갈래와 같게.
    expect(body.substring(guard, guard + 200), contains('_deleteDir(tmpDir)'));
  });

  test('그 까닭을 사람 말로 보여 준다', () {
    // backupFailureMessage가 앱이 쓴 한국어 안내는 그대로 보여 주고,
    // 못 알아볼 글만 '백업 파일이 맞는지...'로 바꾼다. 이 말이 그 검사를
    // 지나지 못하면 사용자는 까닭 대신 엉뚱한 안내를 읽는다.
    expect(
      backupFailureMessage(Exception(backupNothingRestoredMessage),
          type: BackupDialogType.restore),
      backupNothingRestoredMessage,
    );
  });
}
