// 옮기기 실패 안내가 까닭을 지우지 않는지 지킨다(5차 518).
//
// 서버 자리가 모자라거나 구독이 없어서 막힌 것은 사용자가 고칠 수 있는
// 일인데, 전에는 모두 '서버에 저장하지 못했어요. 잠시 뒤 다시 해 주세요'로
// 덮였다. 지우라고도, 구독하라고도 말해 주지 않았다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/services/storage_quota_service.dart';
import 'package:parrokit/core/infrastructure/services/cloud/user_file_storage.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';

void main() {
  test('자리가 모자라면 그 말을 그대로 적는다', () {
    final blocked = ClipTransferBlocked(storageQuotaMessage(
      const StorageQuotaResult(
        allowed: false,
        usedBytes: 10,
        quotaBytes: 10,
        remainingBytes: 0,
        tier: 'light',
      ),
    ));
    expect(
      clipTransferErrorText(blocked, serverSaveFailedMessage),
      '서버가 가득 찼어요. 안 보는 영상을 지우거나 더 큰 단계로 올리면 담을 수 있어요.',
    );
  });

  test('구독이 없어서 막히면 구독 이야기를 적는다', () {
    final blocked = ClipTransferBlocked(storageQuotaMessage(
      const StorageQuotaResult(
        allowed: false,
        usedBytes: 0,
        quotaBytes: 0,
        remainingBytes: 0,
        tier: 'free',
      ),
    ));
    expect(
      clipTransferErrorText(blocked, serverSaveFailedMessage),
      '서버 저장은 구독하면 쓸 수 있어요. 이 영상은 기기에 그대로 있어요.',
    );
  });

  test('R2가 돌려준 말도 그대로 적는다', () {
    expect(
      clipTransferErrorText(
        const UserFileStorageException('네트워크가 불안정해서 올리지 못했어요.',
            code: 'connectionError'),
        serverSaveFailedMessage,
      ),
      '네트워크가 불안정해서 올리지 못했어요.',
    );
  });

  test('속사정은 보여 주지 않고 뭉뚱그린 말을 적는다', () {
    expect(
      clipTransferErrorText(
        StateError('현재 계정의 원격 원본 정보를 찾을 수 없습니다.'),
        serverSaveFailedMessage,
      ),
      serverSaveFailedMessage,
    );
    expect(
      clipTransferErrorText(Exception('boom'), deviceMoveFailedMessage),
      deviceMoveFailedMessage,
    );
  });

  test('클립 하나 옮기기와 여러 개 옮기기 모두 이 말을 쓴다', () {
    // 한쪽만 고치면 다른 쪽에서 또 까닭이 지워진다.
    final source =
        File('lib/core/state/provider/clip_provider.dart').readAsStringSync();
    expect('clipTransferErrorText(e,'.allMatches(source).length, 2);
  });

  test('여러 개 백업은 실제로 옮긴 수만 알린다', () {
    // 자리가 모자라 하나도 못 올렸는데 "5개를 서버에 백업했어요"라고
    // 하면 안 된다. moveClipsToStorage가 옮긴 수를 돌려주고, 호출부는
    // 고른 것을 다 옮겼을 때만 알린다.
    final provider =
        File('lib/core/state/provider/clip_provider.dart').readAsStringSync();
    expect(provider.contains('Future<int> moveClipsToStorage('), isTrue);

    final shell =
        File('lib/core/app/router/app_shell.dart').readAsStringSync();
    expect(shell.contains('final moved = await clipProvider.moveClipsToStorage('),
        isTrue);
    expect(shell.contains('showToast(backupDoneMessage(selectedClipIds.length))'),
        isFalse);
    expect(shell.contains('if (moved >= asked && moved > 0) {'), isTrue);
  });

  // 중간에 막히면 덮개와 토스트가 엇갈렸다(5차 522). 5개를 고르고 3개째까지
  // 올라간 뒤 자리가 모자라 멈추면, 덮개에는 '서버가 가득 찼어요'가,
  // 토스트에는 '3개를 서버에 백업했어요'가 함께 떴다. 못 올린 2개 이야기는
  // 어디에도 없었다.
  test('중간에 멈추면 몇 개까지 갔는지 덮개가 적는다', () {
    expect(
      bulkTransferErrorText('서버가 가득 찼어요.', done: 3, total: 5),
      '3/5개까지 옮겼어요. 서버가 가득 찼어요.',
    );
  });

  test('하나도 못 옮겼으면 숫자를 붙이지 않는다', () {
    expect(
      bulkTransferErrorText('서버가 가득 찼어요.', done: 0, total: 5),
      '서버가 가득 찼어요.',
    );
  });

  test('다 옮기지 못했으면 성공 토스트를 띄우지 않는다', () {
    final shell =
        File('lib/core/app/router/app_shell.dart').readAsStringSync();
    expect(shell.contains('final asked = selectedClipIds.length;'), isTrue);
    expect(shell.contains('if (moved > 0) {'), isFalse);
  });
}
