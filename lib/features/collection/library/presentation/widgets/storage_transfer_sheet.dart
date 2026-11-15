import 'package:flutter/material.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

Future<String?> showStorageTransferSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  String initialMode = ClipStorageConstants.storageModeLocal,
  // 서버 저장 잠금은 로그인 정보를 읽는다. 테스트에서는 값을 넘긴다.
  bool? serverLocked,
}) {
  final cs = Theme.of(context).colorScheme;
  var selectedMode = initialMode;
  // Google Drive 저장은 더 쓰지 않는다(5차). 예전에 Drive에 올린 클립을
  // 열면 기기가 고른 것으로 시작한다.
  if (selectedMode == ClipStorageConstants.storageModeGoogleDrive) {
    selectedMode = ClipStorageConstants.storageModeLocal;
  }
  final isServerLocked =
      serverLocked ?? ClipStorageConstants.isServerStorageLockedForCurrentUser();

  return showAppSheet<String>(
    context: context,
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
                title: '기기',
                subtitle: '이 기기 안에 남겨 둬요.',
                icon: Icons.phone_android_rounded,
                selected: selectedMode == ClipStorageConstants.storageModeLocal,
                onTap: () => setSheetState(
                    () => selectedMode = ClipStorageConstants.storageModeLocal),
              ),
              _StoragePickTile(
                title: '서버',
                subtitle: isServerLocked ? '유료 기능 준비 중이에요.' : '서버로 옮겨요.',
                icon: Icons.cloud_queue_rounded,
                selected:
                    selectedMode == ClipStorageConstants.storageModeServer,
                locked: isServerLocked,
                onTap: isServerLocked
                    ? () => showToast('서버 저장은 준비 중이에요. 출시 후 이용할 수 있어요.')
                    : () => setSheetState(() =>
                        selectedMode = ClipStorageConstants.storageModeServer),
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
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  /// 유료화 준비 등으로 아직 고를 수 없는 항목인지 여부. 탭은 여전히
  /// 눌리지만(안내 토스트 등을 보여줄 수 있도록), 선택 표시 대신 자물쇠
  /// 아이콘을 보여준다.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = cs.primaryContainer.withValues(alpha: 0.55);
    final isDimmed = locked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected && !locked ? activeColor : cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
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
