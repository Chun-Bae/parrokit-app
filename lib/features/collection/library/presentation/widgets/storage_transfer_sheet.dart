import 'package:flutter/material.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

Future<String?> showStorageTransferSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required bool hasGoogleDriveLinked,
  String initialMode = ClipStorageConstants.storageModeLocal,
}) {
  final cs = Theme.of(context).colorScheme;
  var selectedMode = initialMode;
  if (!hasGoogleDriveLinked &&
      selectedMode == ClipStorageConstants.storageModeGoogleDrive) {
    selectedMode = ClipStorageConstants.storageModeServer;
  }
  final isServerLocked =
      ClipStorageConstants.isServerStorageLockedForCurrentUser();

  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              _StoragePickTile(
                title: '로컬',
                subtitle: '이 기기 안에 남겨둡니다.',
                icon: Icons.phone_android_rounded,
                selected: selectedMode == ClipStorageConstants.storageModeLocal,
                onTap: () => setSheetState(
                    () => selectedMode = ClipStorageConstants.storageModeLocal),
              ),
              _StoragePickTile(
                title: '서버',
                subtitle: isServerLocked
                    ? '유료 기능 준비 중이에요.'
                    : '서버 저장으로 옮깁니다.',
                icon: Icons.cloud_queue_rounded,
                selected:
                    selectedMode == ClipStorageConstants.storageModeServer,
                locked: isServerLocked,
                onTap: isServerLocked
                    ? () => showToast('서버 저장은 준비 중이에요. 출시 후 이용할 수 있어요.')
                    : () => setSheetState(() =>
                        selectedMode = ClipStorageConstants.storageModeServer),
              ),
              _StoragePickTile(
                title: 'Google Drive',
                subtitle:
                    hasGoogleDriveLinked ? '내 Drive로 옮깁니다.' : '연동 후 사용할 수 있어요.',
                icon: Icons.cloud_upload_rounded,
                selected:
                    selectedMode == ClipStorageConstants.storageModeGoogleDrive,
                enabled: hasGoogleDriveLinked,
                onTap: hasGoogleDriveLinked
                    ? () => setSheetState(() => selectedMode =
                        ClipStorageConstants.storageModeGoogleDrive)
                    : null,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, selectedMode),
                child: const Text('적용'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StoragePickTile extends StatelessWidget {
  const _StoragePickTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  /// 유료화 준비 등으로 아직 고를 수 없는 항목인지 여부. 탭은 여전히
  /// 눌리지만(안내 토스트 등을 보여줄 수 있도록), 선택 표시 대신 자물쇠
  /// 아이콘을 보여준다.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = cs.primaryContainer.withValues(alpha: 0.55);
    final isDimmed = !enabled || locked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected && !locked ? activeColor : cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: isDimmed ? cs.onSurfaceVariant : cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  locked
                      ? Icons.lock_rounded
                      : (selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_off),
                  color: isDimmed ? cs.onSurfaceVariant : cs.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
