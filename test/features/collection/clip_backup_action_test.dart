// 클립 백업은 구독이 정한다. 위치를 고르는 시트는 없앴다(5차 5단계).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/clip_backup_action.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('구독 중일 때만 서버에 백업할 수 있다', () {
    expect(canBackUpToServer(SubscriptionTier.free), isFalse);
    expect(canBackUpToServer(SubscriptionTier.light), isTrue);
    expect(canBackUpToServer(SubscriptionTier.pro), isTrue);
  });

  test('못 하는 까닭과 함께 영상이 남아 있다는 것을 알린다', () {
    expect(backupNeedsSubscriptionMessage, contains('구독하면'));
    expect(backupNeedsSubscriptionMessage, contains('이 기기에 그대로'));
  });

  test('백업한 수만큼 말이 달라진다', () {
    expect(backupDoneMessage(1), '서버에 백업했어요.');
    expect(backupDoneMessage(3), '3개를 서버에 백업했어요.');
  });

  test('이미 서버에 있는 클립은 다시 올리지 않는다', () {
    expect(isBackedUp(ClipStorageConstants.storageModeServer), isTrue);
    expect(isBackedUp(ClipStorageConstants.storageModeLocal), isFalse);
    expect(backupAlreadyDoneMessage, '이미 백업돼 있어요.');
  });

  test('저장 위치를 고르는 시트는 더 없다', () {
    expect(
        File('lib/features/collection/library/presentation/widgets/storage_transfer_sheet.dart')
            .existsSync(),
        isFalse);
    for (final path in [
      'lib/features/collection/library/presentation/widgets/clip_list_view.dart',
      'lib/core/app/router/app_shell.dart',
    ]) {
      final code = _code(path);
      expect(code.contains('showStorageTransferSheet'), isFalse, reason: path);
      expect(code, contains('ensureBackupAllowed'), reason: path);
    }
  });
}
