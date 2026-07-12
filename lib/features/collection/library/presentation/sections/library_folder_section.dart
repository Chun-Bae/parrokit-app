// ============================================================================
// lib/features/_content/library/presentation/sections/library_folder_section.dart
// ============================================================================
//
// [역할]
// 라이브러리 화면의 "폴더" 탭 섹션 (Breadcrumb + Grid/List)
//
// [레이어]
// Presentation Layer > Sections
//
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/shared/widgets/expandable_action_fab.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/folder_grid.dart';
import '../widgets/group_collection_manager_modal.dart';
import '../widgets/clip_list_view.dart';

/// [역할]
/// 라이브러리의 '폴더' 탭 UI 섹션.
///
/// [계층 구조]
/// 1. Collections (컬렉션)
/// 2. Clips (클립)
class LibraryFolderSection extends StatefulWidget {
  const LibraryFolderSection({super.key});

  @override
  State<LibraryFolderSection> createState() => _LibraryFolderSectionState();
}

class _LibraryFolderSectionState extends State<LibraryFolderSection> {
  bool _deleteMode = false;
  bool _isGridView = true;
  bool _isFabExtended = true;

  void _toggleDeleteMode() => setState(() => _deleteMode = !_deleteMode);
  void _toggleViewMode() => setState(() => _isGridView = !_isGridView);

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  Widget _buildServerStorageProgress(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    final cs = Theme.of(context).colorScheme;
    final used = clipProvider.serverStorageUsedBytes;
    final total = ClipProvider.serverStorageQuotaBytes;
    final progress = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final isFull = used >= total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage_rounded,
                  size: 18,
                  color: isFull ? cs.error : cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '서버 저장 용량',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                  ),
                ),
                Text(
                  '${_formatBytes(used)} / ${_formatBytes(total)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFull ? cs.error : cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFull
                  ? '서버 용량이 가득 찼습니다. 새 파일을 저장하려면 공간을 확보하세요.'
                  : '서버에 저장 가능한 공간이 제한되어 있습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 현재 활성 저장위치 탭에 해당하는 사용량 카드 하나만 보여줍니다.
  /// (탭이 저장위치별로 분리된 이상, 3개를 한꺼번에 보여주는 건 중복입니다)
  Widget _buildActiveStorageSummary(BuildContext context, String storageMode) {
    return switch (storageMode) {
      ClipStorageConstants.storageModeServer =>
        _buildServerStorageProgress(context),
      ClipStorageConstants.storageModeGoogleDrive =>
        _buildCloudStorageSummary(context),
      _ => _buildLocalStorageSummary(context),
    };
  }

  Widget _buildUsageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String usageText,
    required String description,
    required Color color,
    double? progress,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                ),
              ),
              Text(
                usageText,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalStorageSummary(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: _buildUsageCard(
        context,
        icon: Icons.phone_android_rounded,
        title: '로컬 저장 용량',
        usageText: _formatBytes(clipProvider.localStorageUsedBytes),
        description: '인터넷이 없어도 바로 열 수 있도록 이 기기에 남아 있는 파일입니다.',
        color: Theme.of(context).colorScheme.tertiary,
      ),
    );
  }

  Widget _buildCloudStorageSummary(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    final quota = clipProvider.cloudStorageQuotaBytes;
    final used = clipProvider.googleDriveUsedBytes;
    final parrokitUsed = clipProvider.cloudStorageUsedBytes;
    final hasQuota = quota != null && quota > 0;
    final isLinked = clipProvider.hasGoogleDriveLinked;
    final isBusy = clipProvider.isGoogleDriveLinking;
    final otherUsed = math.max(used - parrokitUsed, 0);
    final remaining = hasQuota ? math.max(quota - used, 0) : 0;
    final segments = hasQuota
        ? <_StorageSegment>[
            _StorageSegment(
              value: otherUsed,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            _StorageSegment(
              value: parrokitUsed,
              color: Theme.of(context).colorScheme.primary,
            ),
            _StorageSegment(
              value: remaining,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ]
        : <_StorageSegment>[
            _StorageSegment(
              value: otherUsed,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            _StorageSegment(
              value: parrokitUsed,
              color: Theme.of(context).colorScheme.primary,
            ),
          ];
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_queue_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLinked ? 'Google Drive 연동됨' : 'Google Drive 저장 용량',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () async {
                          final provider = context.read<ClipProvider>();
                          final messenger = ScaffoldMessenger.of(context);
                          if (provider.hasGoogleDriveLinked) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Google Drive 연동 해제'),
                                content: const Text(
                                  '연동을 해제하면 Google Drive에 있던 파일들을 모두 기기로 옮긴 뒤, 계정을 분리합니다.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('취소'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('연동 해제'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;

                            final success =
                                await provider.disconnectGoogleDrive();
                            if (!context.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Google Drive 연동을 해제했어요.'
                                      : 'Google Drive 연동 해제에 실패했어요.',
                                ),
                              ),
                            );
                          } else {
                            final success = await provider.connectGoogleDrive();
                            if (!context.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Google Drive 연동을 완료했어요.'
                                      : 'Google Drive 연동에 실패했어요.',
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(isLinked ? '연동 해제' : '구글 드라이브 연동하기'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSegmentedBar(context, segments: segments),
            const SizedBox(height: 8),
            Text(
              hasQuota
                  ? 'Drive 전체 사용량 안에서 Parrokit가 차지하는 실제 크기를 따로 분리해 보여줍니다.'
                  : 'Drive 전체 사용량을 모두 가져오지 못해서 Parrokit 사용량 중심으로 보여줍니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildLegendChip(
                  context,
                  label: 'Parrokit ${_formatBytes(parrokitUsed)}',
                  color: cs.primary,
                ),
                _buildLegendChip(
                  context,
                  label: '기타 파일 ${_formatBytes(otherUsed)}',
                  color: cs.surfaceContainerHigh,
                ),
                if (hasQuota)
                  _buildLegendChip(
                    context,
                    label: '남은 공간 ${_formatBytes(remaining)}',
                    color: cs.surfaceContainerHighest,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedBar(
    BuildContext context, {
    required List<_StorageSegment> segments,
  }) {
    final cs = Theme.of(context).colorScheme;
    final visibleSegments =
        segments.where((segment) => segment.value > 0).toList();
    final effectiveSegments = visibleSegments.isEmpty
        ? [
            _StorageSegment(
              value: 1,
              color: cs.surfaceContainerHigh,
            ),
          ]
        : visibleSegments;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: effectiveSegments
              .map(
                (segment) => Expanded(
                  flex: math.max(segment.value, 1),
                  child: Container(color: segment.color),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildLegendChip(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Future<T?> _showUnifiedBottomSheet<T>(
    BuildContext context, {
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: child,
        ),
      ),
    );
  }

  void _showFabMenu(BuildContext fabCtx, bool isAtGroupRoot) {
    final cs = Theme.of(fabCtx).colorScheme;

    _showUnifiedBottomSheet<String>(
      fabCtx,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAtGroupRoot ? '그룹 메뉴' : '콜렉션 메뉴',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              isAtGroupRoot
                  ? '그룹을 추가하거나 그룹 관리로 이동할 수 있어요.'
                  : '콜렉션을 추가하거나 삭제 모드로 들어갈 수 있어요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.add_rounded, color: cs.primary),
              title: Text(isAtGroupRoot ? '그룹 추가' : '콜렉션 추가'),
              onTap: () => Navigator.pop(context, 'add'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: cs.error),
              title: Text('삭제 모드', style: TextStyle(color: cs.error)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: Icon(Icons.settings_suggest_rounded, color: cs.primary),
              title: const Text('그룹/콜렉션 관리'),
              onTap: () => Navigator.pop(context, 'manage'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((value) {
      if (!mounted) return;
      if (value == 'add') {
        if (isAtGroupRoot) {
          _showCreateGroupDialog(context);
        } else {
          _showCreateCollectionDialog(context);
        }
      } else if (value == 'delete') {
        setState(() => _deleteMode = true);
      } else if (value == 'manage') {
        final clipProvider = context.read<ClipProvider>();
        final cs = Theme.of(context).colorScheme;
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: cs.surface,
          barrierColor: Colors.black.withValues(alpha: 0.42),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          builder: (_) => GroupCollectionManagerModal(
            initialGroupId: clipProvider.selectedGroupId == -1
                ? null
                : clipProvider.selectedGroupId,
          ),
        );
      }
    });
  }

  Future<void> _showDeleteGroupDialog(
    BuildContext context,
    int groupId,
    String name,
  ) async {
    if (!context.mounted) return;
    final cs = Theme.of(context).colorScheme;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그룹 삭제'),
        content: Text("'$name' 그룹을 삭제할까요?\n(그룹 내 콜렉션과 클립은 삭제되지 않습니다)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await context.read<ClipProvider>().deleteGroupById(groupId);
    }
  }

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final clipProvider = context.read<ClipProvider>();
    await _showNameEntryDialog(
      context,
      title: '그룹 추가',
      hint: '그룹 이름',
      submitLabel: '추가',
      onSubmit: (name) => clipProvider.createGroup(name),
    );
  }

  Future<void> _showRenameGroupDialog(
    BuildContext context,
    int groupId,
    String currentName,
  ) async {
    final clipProvider = context.read<ClipProvider>();
    await _showNameEntryDialog(
      context,
      title: '그룹 이름 변경',
      hint: '그룹 이름',
      submitLabel: '변경',
      initialText: currentName,
      onSubmit: (name) => clipProvider.renameGroup(groupId, name),
    );
  }

  Future<void> _showRenameCollectionDialog(
    BuildContext context,
    int collectionId,
    String currentName,
  ) async {
    final clipProvider = context.read<ClipProvider>();
    await _showNameEntryDialog(
      context,
      title: '컬렉션 이름 변경',
      hint: '컬렉션 이름',
      submitLabel: '변경',
      initialText: currentName,
      onSubmit: (name) => clipProvider.renameCollection(collectionId, name),
    );
  }

  /// 그룹/콜렉션 생성·이름변경 다이얼로그 공용 헬퍼.
  ///
  /// 서버/클라우드 탭에서는 [onSubmit] 안에서 원격 업로드 네트워크 호출이
  /// 일어나 즉시 끝나지 않으므로, 제출 중에는 버튼을 비활성화하고 로딩
  /// 표시를 보여줘서 사용자가 다시 눌러 중복 제출하는 걸 막습니다.
  Future<void> _showNameEntryDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required String submitLabel,
    String initialText = '',
    required Future<void> Function(String name) onSubmit,
  }) async {
    final ctl = TextEditingController(text: initialText);
    final clipProvider = context.read<ClipProvider>();
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> handleSubmit() async {
            if (submitting) return;
            final name = ctl.text.trim();
            if (name.isEmpty || name == initialText) {
              Navigator.pop(ctx);
              return;
            }
            final exists = await clipProvider.isNameExists(name);
            if (exists) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('이미 같은 이름의 그룹이나 컬렉션이 존재합니다.')),
                );
              }
              return;
            }
            setState(() => submitting = true);
            try {
              await onSubmit(name);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (_) {
              if (ctx.mounted) {
                setState(() => submitting = false);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('처리 중 오류가 발생했습니다. 다시 시도해주세요.')),
                );
              }
            }
          }

          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: ctl,
              autofocus: true,
              enabled: !submitting,
              decoration: InputDecoration(hintText: hint),
              onSubmitted: (_) => handleSubmit(),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: submitting ? null : handleSubmit,
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(submitLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteCollectionDialog(
    BuildContext context,
    int collectionId,
    String name,
  ) async {
    final clipProvider = context.read<ClipProvider>();
    final clipCount = await clipProvider.countClipsInCollection(collectionId);
    if (!context.mounted) return;

    final cs = Theme.of(context).colorScheme;
    final content = clipCount > 0
        ? "'$name' 컬렉션과 포함된 클립 $clipCount개를 모두 삭제할까요?\n\n이 작업은 되돌릴 수 없습니다."
        : "'$name' 컬렉션을 삭제할까요?";

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('컬렉션 삭제'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await context.read<ClipProvider>().deleteCollectionById(collectionId);
    }
  }

  Future<void> _showCreateCollectionDialog(BuildContext context) async {
    final clipProvider = context.read<ClipProvider>();
    await _showNameEntryDialog(
      context,
      title: '컬렉션 추가',
      hint: '컬렉션 이름',
      submitLabel: '추가',
      onSubmit: (name) => clipProvider.createCollection(name),
    );
  }

  Future<void> _showClipFabMenu(
    BuildContext context, {
    required String? selectedCollectionName,
    required bool canAddClip,
  }) async {
    final clipProvider = context.read<ClipProvider>();
    final router = GoRouter.of(context);
    final cs = Theme.of(context).colorScheme;

    final action = await _showUnifiedBottomSheet<String>(
      context,
      child: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '클립 메뉴',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              canAddClip
                  ? '클립을 추가하거나 선택 모드로 바꿀 수 있어요.'
                  : '클립을 선택 모드로 바꿀 수 있어요.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (canAddClip)
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('클립 추가'),
                onTap: () => Navigator.pop(ctx, 'add'),
              ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('선택 모드'),
              onTap: () => Navigator.pop(ctx, 'select'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;

    switch (action) {
      case 'add':
        final colName = Uri.encodeComponent(selectedCollectionName ?? '');
        router.push(
          '${AppRoutes.clipsPath}/${AppRoutes.clipsCreatePath}?collectionName=$colName',
        );
        break;
      case 'select':
        clipProvider.openCollectionMenu();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    final cs = Theme.of(context).colorScheme;
    final isSelectionMode = clipProvider.isCollectionMenuOpen &&
        clipProvider.selectedCollectionId != null;

    // Breadcrumbs 생성
    final crumbs = <String>['미디어 보관함'];
    String? selectedGroupName;
    String? selectedCollectionName;

    if (clipProvider.selectedGroupId != null) {
      if (clipProvider.selectedGroupId == -1) {
        selectedGroupName = '모든 콜렉션';
        crumbs.add(selectedGroupName);
      } else {
        final grp = clipProvider.groups.cast<dynamic>().firstWhere(
              (g) => (g.id as int) == clipProvider.selectedGroupId,
              orElse: () => null,
            );
        if (grp != null) {
          selectedGroupName = grp.name as String;
          crumbs.add(selectedGroupName);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<ClipProvider>().backToGroups();
            }
          });
        }
      }
    }

    if (clipProvider.selectedCollectionId != null) {
      if (clipProvider.selectedCollectionId == -1) {
        selectedCollectionName =
            clipProvider.selectedGroupId == -1 ? '모든 클립' : '그룹 내 모든 클립';
        crumbs.add(selectedCollectionName);
      } else {
        final col = clipProvider.collections.cast<dynamic>().firstWhere(
              (c) => (c.id as int) == clipProvider.selectedCollectionId,
              orElse: () => null,
            );
        if (col != null) {
          selectedCollectionName = col.name as String;
          crumbs.add(selectedCollectionName);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<ClipProvider>().backToCollections();
            }
          });
        }
      }
    }

    final isAtClipList = clipProvider.selectedCollectionId != null;
    final isAtCollectionList = clipProvider.selectedGroupId != null &&
        clipProvider.selectedCollectionId == null;
    final isAtGroupRoot = clipProvider.selectedGroupId == null;

    // 클립 목록으로 들어오면 삭제 모드 자동 해제
    if (isAtClipList && _deleteMode) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => _deleteMode = false));
    }

    return Stack(
      children: [
        Column(
          children: [
            if (!isSelectionMode) ...[
              BreadcrumbBar(
                path: crumbs,
                onTapCrumb: (i) {
                  if (i == 0) {
                    setState(() => _deleteMode = false);
                    clipProvider.backToGroups();
                  } else if (i == 1 && crumbs.length > 2) {
                    setState(() => _deleteMode = false);
                    clipProvider.backToCollections();
                  }
                },
              ),

              _buildActiveStorageSummary(
                  context, clipProvider.activeStorageMode),

              // 삭제 모드 배너
              if (_deleteMode && !isAtClipList)
                Container(
                  color: cs.errorContainer,
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 16, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Text('삭제 모드 — 컬렉션을 눌러 삭제',
                          style: TextStyle(
                              color: cs.onErrorContainer, fontSize: 13)),
                      const Spacer(),
                      TextButton(
                        onPressed: _toggleDeleteMode,
                        child: Text('완료',
                            style: TextStyle(color: cs.onErrorContainer)),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  if (notification.direction == ScrollDirection.reverse) {
                    if (_isFabExtended) setState(() => _isFabExtended = false);
                  } else if (notification.direction ==
                      ScrollDirection.forward) {
                    if (!_isFabExtended) setState(() => _isFabExtended = true);
                  }
                  return false;
                },
                child: Builder(
                  builder: (_) {
                    if (isAtGroupRoot) {
                      final gridItems = [
                        '모든 콜렉션',
                        ...clipProvider.groups
                            .map((g) => (g as dynamic).name as String)
                      ];
                      return FolderGrid(
                        sectionTitle: '그룹',
                        items: gridItems,
                        deleteMode: _deleteMode,
                        isGridView: _isGridView,
                        onToggleView: _toggleViewMode,
                        onAdd: () => _showCreateGroupDialog(context),
                        onTap: (idx) {
                          if (idx == 0) {
                            if (!_deleteMode) {
                              clipProvider.selectGroup(-1);
                            }
                            return;
                          }

                          final grp = clipProvider.groups[idx - 1];
                          if (_deleteMode) {
                            _showDeleteGroupDialog(context, grp.id, grp.name);
                          } else {
                            clipProvider.selectGroup(grp.id);
                          }
                        },
                        onLongPress: (idx) {
                          if (idx == 0) return;
                          final grp = clipProvider.groups[idx - 1];
                          _showRenameGroupDialog(context, grp.id, grp.name);
                        },
                      );
                    }

                    // 2) Collections
                    if (isAtCollectionList) {
                      final allClipsLabel = clipProvider.selectedGroupId == -1
                          ? '모든 클립'
                          : '그룹 내 모든 클립';
                      final gridItems = [
                        allClipsLabel,
                        ...clipProvider.collections
                            .map((c) => (c as dynamic).name as String)
                      ];
                      return FolderGrid(
                        sectionTitle: '컬렉션',
                        items: gridItems,
                        deleteMode: _deleteMode,
                        isGridView: _isGridView,
                        onToggleView: _toggleViewMode,
                        onAdd: () => _showCreateCollectionDialog(context),
                        onTap: (idx) {
                          if (idx == 0) {
                            if (!_deleteMode) {
                              clipProvider.selectCollection(-1);
                            }
                            return;
                          }

                          final col = clipProvider.collections[idx - 1];
                          if (_deleteMode) {
                            _showDeleteCollectionDialog(
                                context, col.id, col.name);
                          } else {
                            clipProvider.selectCollection(col.id);
                          }
                        },
                        onLongPress: (idx) {
                          if (idx == 0) return;
                          final col = clipProvider.collections[idx - 1];
                          _showRenameCollectionDialog(
                              context, col.id, col.name);
                        },
                      );
                    }

                    // 3) Clips
                    return ClipListView(
                      items: clipProvider.clipItems,
                      selectionMode: isSelectionMode,
                      selectedClipIds: clipProvider.selectedClipIds,
                      onToggleSelection: (item) {
                        clipProvider.toggleClipSelection(item.clip.id);
                      },
                      onOpen: (ci) {
                        context.push(
                          '${AppRoutes.clipsPath}/${AppRoutes.clipsPlayPath}?clipId=${ci.clip.id}',
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        // FAB
        if (!isSelectionMode)
          Positioned(
            right: 16,
            bottom: 16,
            child: Builder(
              builder: (fabCtx) {
                final colorScheme = Theme.of(fabCtx).colorScheme;
                return ExpandableActionFab(
                  isExtended: _isFabExtended,
                  icon: isAtClipList
                      ? Icons.tune_rounded
                      : Icons.more_horiz_rounded,
                  label: isAtClipList
                      ? '클립 메뉴'
                      : (isAtGroupRoot ? '그룹 메뉴' : '콜렉션 메뉴'),
                  onTap: isAtClipList
                      ? () => _showClipFabMenu(
                            fabCtx,
                            selectedCollectionName: selectedCollectionName,
                            canAddClip: clipProvider.selectedCollectionId != -1,
                          )
                      : () => _showFabMenu(fabCtx, isAtGroupRoot),
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.primary,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  fontSize: 16,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _StorageSegment {
  const _StorageSegment({
    required this.value,
    required this.color,
  });

  final int value;
  final Color color;
}
