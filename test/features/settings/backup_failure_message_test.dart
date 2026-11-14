// 백업·불러오기 실패 안내가 내부 오류 글을 내보내지 않게 지킨다(5차).
//
// 전에는 `e.toString()`을 그대로 창에 띄웠다. 앱이 직접 던진 짧은 한국어
// 안내는 도움이 되니 그대로 쓰고, 그 밖의 예외 글은 사람 말로 바꾼다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/backup_progress_dialog.dart';

void main() {
  test('앱이 던진 한국어 안내는 그대로 보여 준다', () {
    expect(
      backupFailureMessage(Exception('파일을 고르지 않았어요.'),
          type: BackupDialogType.restore),
      '파일을 고르지 않았어요.',
    );
  });

  test('내부 예외 글은 사람 말 안내로 바꾼다', () {
    final backup = backupFailureMessage(
      Exception('FileSystemException: No space left on device, path = /tmp/x'),
      type: BackupDialogType.backup,
    );
    expect(backup, '백업하지 못했어요. 저장 공간을 확인하고 다시 해 보세요.');

    final restore = backupFailureMessage(
      StateError('Bad state: no element'),
      type: BackupDialogType.restore,
    );
    expect(restore, '불러오지 못했어요. 백업 파일이 맞는지 확인하고 다시 해 보세요.');
  });

  test('경로나 null이 섞인 한글 글도 감춘다', () {
    final message = backupFailureMessage(
      Exception('백업 파일 /var/mobile/Containers/a.zip 없음'),
      type: BackupDialogType.restore,
    );
    expect(message.contains('/var'), isFalse);
  });
}
