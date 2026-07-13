import 'package:flutter/material.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'bookmark_tab.dart';

/// [역할]
/// 라이브러리 상단의 저장위치 탭 전환 위젯 (로컬 / 서버 / 클라우드).
///
/// 그룹→콜렉션→클립 트리를 저장위치별로 완전히 독립적으로 보여주기 위한
/// 탭으로, [BookmarkTabs]와 같은 시각적 언어(세그먼트 컨트롤)를 3개 항목으로
/// 확장한 위젯입니다.
class StorageScopeTabs extends StatelessWidget {
  const StorageScopeTabs({super.key, required this.value, required this.onChanged});

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
    final cs = Theme.of(context).colorScheme;
    final activeIndex = _items.indexWhere((item) => item.mode == value);
    final alignX = activeIndex <= 0 ? -1.0 : (activeIndex >= 2 ? 1.0 : 0.0);
    final isServerLocked =
        ClipStorageConstants.isServerStorageLockedForCurrentUser();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
          border: Border.all(color: cs.outlineVariant, width: 0.8),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(alignX, 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: FractionallySizedBox(
                widthFactor: 1 / _items.length,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: cs.primary.withValues(alpha: 0.5), width: 0.8),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final item in _items) ...[
                  Expanded(
                    child: BookmarkTab(
                      icon: item.icon,
                      label: item.label,
                      active: item.mode == value,
                      locked: item.mode == ClipStorageConstants.storageModeServer &&
                          isServerLocked,
                      onTap: () {
                        if (item.mode == ClipStorageConstants.storageModeServer &&
                            isServerLocked) {
                          showToast('서버 저장은 준비 중이에요. 출시 후 이용할 수 있어요.');
                          return;
                        }
                        onChanged(item.mode);
                      },
                    ),
                  ),
                  if (item != _items.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
