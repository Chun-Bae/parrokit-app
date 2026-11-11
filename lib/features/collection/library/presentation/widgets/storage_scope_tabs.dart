import 'package:flutter/material.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';

/// [역할]
/// 라이브러리 상단의 저장위치 탭 전환 위젯 (로컬 / 서버 / 클라우드).
///
/// 그룹→콜렉션→클립 트리를 저장위치별로 완전히 독립적으로 보여주기 위한 탭이다.
/// 생김새는 앱 전역 세그먼트 컨트롤([AppSegmentedTabs])을 그대로 쓴다.
class StorageScopeTabs extends StatelessWidget {
  const StorageScopeTabs(
      {super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _items = [
    (
      mode: ClipStorageConstants.storageModeLocal,
      icon: Icons.phone_android_rounded,
      label: '로컬',
    ),
    (
      mode: ClipStorageConstants.storageModeServer,
      icon: Icons.cloud_queue_rounded,
      label: '서버',
    ),
    (
      mode: ClipStorageConstants.storageModeGoogleDrive,
      icon: Icons.cloud_upload_rounded,
      label: '클라우드',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isServerLocked =
        ClipStorageConstants.isServerStorageLockedForCurrentUser();
    bool lockedAt(int index) =>
        _items[index].mode == ClipStorageConstants.storageModeServer &&
        isServerLocked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AppSegmentedTabs(
        selectedIndex: _items.indexWhere((item) => item.mode == value),
        onChanged: (index) {
          if (lockedAt(index)) {
            showToast('서버 저장은 준비 중이에요. 출시 후 이용할 수 있어요.');
            return;
          }
          onChanged(_items[index].mode);
        },
        segments: [
          for (var i = 0; i < _items.length; i++)
            AppSegment(
              icon: _items[i].icon,
              label: _items[i].label,
              locked: lockedAt(i),
            ),
        ],
      ),
    );
  }
}
