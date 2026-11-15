// 클립을 서버에 백업하는 길. 저장 위치는 사용자가 고르지 않고 구독이 정한다(5차 5단계).
//
// 전에는 '기기 / 서버' 중에 고르는 시트를 띄웠다. 무료 사용자에게는 고를 수
// 없는 선택지를 보여 주는 셈이었고, 구독자에게는 한 번 더 누르게 할 뿐이었다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

/// 서버 백업을 쓸 수 없을 때 하는 말. 영상이 그대로 있다는 것을 함께 알린다.
const String backupNeedsSubscriptionMessage =
    '서버 백업은 구독하면 쓸 수 있어요. 영상은 이 기기에 그대로 있어요.';

/// 이미 서버에 있는 클립을 또 누를 때.
const String backupAlreadyDoneMessage = '이미 백업돼 있어요.';

/// 백업이 끝났을 때.
String backupDoneMessage(int count) =>
    count == 1 ? '서버에 백업했어요.' : '$count개를 서버에 백업했어요.';

/// 이 사람이 서버에 백업할 수 있는지. 구독 중이어야 한다.
bool canBackUpToServer(SubscriptionTier tier) => tier != SubscriptionTier.free;

/// 구독 중이 아니면 까닭을 알리고 구독 화면으로 갈 수 있게 한다.
/// 백업을 할 수 있으면 true.
bool ensureBackupAllowed(BuildContext context, {PaywallPresenter? presenter}) {
  final tier = context.read<SubscriptionProvider>().tier;
  if (canBackUpToServer(tier)) return true;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: const Text(backupNeedsSubscriptionMessage),
    duration: const Duration(seconds: 4),
    action: SnackBarAction(
      label: '구독 보기',
      onPressed: () => (presenter ?? resolvePaywallPresenter()).show(context),
    ),
  ));
  return false;
}

/// 이 클립이 이미 서버에 있는지.
bool isBackedUp(String storageMode) =>
    storageMode == ClipStorageConstants.storageModeServer;

/// 이미 백업된 클립을 또 누르면 알려만 준다.
void showAlreadyBackedUp() => showToast(backupAlreadyDoneMessage);
