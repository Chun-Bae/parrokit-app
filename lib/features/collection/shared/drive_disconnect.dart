// Google Drive 연동 해제를 묻고 알리는 한 곳(5차 422).
//
// 같은 확인 창과 알림이 두 화면(더보기 > 저장 용량 시트, 보관함 폴더 섹션)에
// 마흔 줄씩 통째로 복사돼 있었다. 한쪽만 고치면 말이 갈린다.
//
// Drive 저장은 더 쓰지 않는다. 새로 연동하는 길은 뺐고, 이미 연동한
// 사람에게 해제만 남긴다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';

const String driveDisconnectTitle = 'Google Drive 연동 해제';
const String driveDisconnectBody =
    '연동을 해제하면 Google Drive에 있던 파일을 모두 이 기기로 옮긴 뒤 계정을 떼어 내요.';
const String driveDisconnectConfirmLabel = '연동 해제';
const String driveDisconnectCancelLabel = '취소';
const String driveDisconnectedMessage = 'Google Drive 연동을 해제했어요.';
const String driveDisconnectFailedMessage = 'Google Drive 연동 해제에 실패했어요.';

/// 연동 해제를 묻고, 눌렀으면 해제한 뒤 결과를 알린다.
/// 묻는 창에서 그만두면 아무것도 하지 않는다.
Future<void> confirmAndDisconnectGoogleDrive(BuildContext context) async {
  final provider = context.read<ClipProvider>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(driveDisconnectTitle),
      content: const Text(driveDisconnectBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(driveDisconnectCancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(driveDisconnectConfirmLabel),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final success = await provider.disconnectGoogleDrive();
  if (!context.mounted) return;
  showToast(success ? driveDisconnectedMessage : driveDisconnectFailedMessage);
}

/// 파일을 옮기는 동안 진행 막대에 적는 글. 레포지토리가 한 걸음마다
/// 같은 글을 보내 와서, 글을 여기 두고 양쪽이 함께 쓴다.
const String driveMovingToDeviceMessage = 'Google Drive 파일을 이 기기로 옮기는 중';

/// 연결하지 못했을 때(새로 연결하는 길은 없앴지만, 길이 남아 있는 동안은
/// 예외 글 대신 이 말을 보여 준다).
const String driveConnectFailedMessage =
    'Google Drive에 연결하지 못했어요. 잠시 뒤 다시 해 주세요.';
