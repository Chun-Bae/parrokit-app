import 'package:flutter/material.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/collection/library/presentation/providers/tag_filter_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'episode_thumbnail.dart';
import 'swipe_action_tile.dart';
import 'mini_chip.dart';
import 'storage_transfer_sheet.dart';

class ClipListView extends StatelessWidget {
  const ClipListView({
    super.key,
    required this.items,
    required this.onOpen,
    this.selectionMode = false,
    this.selectedClipIds = const <int>{},
    this.onToggleSelection,
    this.resolveThumb,
  });

  final List<ClipItem> items;
  final ValueChanged<ClipItem> onOpen;
  final bool selectionMode;
  final Set<int> selectedClipIds;
  final ValueChanged<ClipItem>? onToggleSelection;
  final ImageProvider<Object>? Function(ClipItem item)? resolveThumb;

  String _fmtMs(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}분 ${s.toString().padLeft(2, '0')}초';
  }

  String? _storageLabel(String storageMode) {
    if (storageMode == ClipStorageConstants.storageModeLocal) return '로컬';
    if (storageMode == ClipStorageConstants.storageModeServer) return '서버';
    if (storageMode == ClipStorageConstants.storageModeGoogleDrive) {
      return '클라우드 · Google Drive';
    }

    return null;
  }

  Widget? _buildStorageChip(BuildContext context, String storageMode) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final label = _storageLabel(storageMode);

    if (label == null) return null;

    final isCloud = storageMode == ClipStorageConstants.storageModeGoogleDrive;

    final background = switch (storageMode) {
      ClipStorageConstants.storageModeLocal =>
        cs.secondaryContainer.withValues(alpha: 0.55),
      ClipStorageConstants.storageModeServer =>
        cs.tertiaryContainer.withValues(alpha: 0.55),
      _ when isCloud => cs.primaryContainer.withValues(alpha: 0.55),
      _ => cs.secondaryContainer.withValues(alpha: 0.55),
    };

    final foreground = switch (storageMode) {
      ClipStorageConstants.storageModeLocal =>
        cs.onSecondaryContainer.withValues(alpha: 0.9),
      ClipStorageConstants.storageModeServer =>
        cs.onTertiaryContainer.withValues(alpha: 0.9),
      _ when isCloud => cs.onPrimaryContainer.withValues(alpha: 0.9),
      _ => cs.onSecondaryContainer.withValues(alpha: 0.9),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Future<void> _refreshClipListAfterStorageChange(
    ClipProvider provider,
  ) async {
    await provider.selectCollection(provider.selectedCollectionId);
  }

  Future<bool> _moveToLocal(
    ClipProvider provider,
    ClipItem item,
  ) async {
    final success = await provider.moveClipToLocal(item.clip.id);
    if (!success) return false;

    await _refreshClipListAfterStorageChange(provider);
    return true;
  }

  Future<bool> _moveToServer(
    ClipProvider provider,
    ClipItem item,
  ) async {
    final success = await provider.moveClipToServer(item.clip.id);
    if (!success) return false;

    await _refreshClipListAfterStorageChange(provider);
    return true;
  }

  Future<bool> _moveToGoogleDrive(
    ClipProvider provider,
    ClipItem item,
  ) async {
    final success = await provider.moveClipToGoogleDrive(item.clip.id);
    if (!success) return false;

    await _refreshClipListAfterStorageChange(provider);
    return true;
  }

  void _showStorageModeSheet(
    BuildContext context,
    ClipItem item, {
    required VoidCallback onApplied,
  }) {
    final provider = context.read<ClipProvider>();
    showStorageTransferSheet(
      context,
      title: '저장 위치 바꾸기',
      subtitle: '원하는 위치를 고르면, 기기 안에 남겨둘지도 함께 정할 수 있어요.',
      hasGoogleDriveLinked: provider.hasGoogleDriveLinked,
      initialMode: item.clip.storageMode,
    ).then((target) async {
      if (!context.mounted || target == null) return;
      final success = switch (target) {
        ClipStorageConstants.storageModeLocal =>
          await _moveToLocal(provider, item),
        ClipStorageConstants.storageModeServer =>
          await _moveToServer(provider, item),
        ClipStorageConstants.storageModeGoogleDrive =>
          await _moveToGoogleDrive(provider, item),
        _ => false,
      };

      if (success) {
        onApplied();
        if (target == ClipStorageConstants.storageModeServer) {
          showToast('서버에 저장했어요.');
        } else if (target == ClipStorageConstants.storageModeLocal) {
          showToast('로컬로 옮겼어요.');
        } else if (target == ClipStorageConstants.storageModeGoogleDrive) {
          showToast('Google Drive에 저장했어요.');
        }
      } else if (target == ClipStorageConstants.storageModeServer) {
        showToast('서버 저장에 실패했어요.');
      } else if (target == ClipStorageConstants.storageModeLocal) {
        showToast('로컬 전환에 실패했어요.');
      } else if (target == ClipStorageConstants.storageModeGoogleDrive) {
        showToast('Google Drive 저장에 실패했어요.');
      }
    });
  }

  Widget _buildSwipeAction({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: double.infinity,
            color: color,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteClip(BuildContext context, ClipItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '삭제할까요?',
          style: Theme.of(dialogContext)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          item.clip.title,
          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
              ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (!context.mounted) return;
      final ok2 =
          await context.read<ClipProvider>().deleteClipById(item.clip.id);

      if (!context.mounted) return;
      // ✅ showToast 사용
      showToast(ok2 ? '삭제되었습니다' : '삭제에 실패했습니다');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: buildSlivers(context));
  }

  /// 다른 스크롤 영역(예: 상위 화면의 [CustomScrollView])에 이어붙일 수
  /// 있도록 슬리버 목록만 뽑아낸 것. [build]도 이 목록을 그대로 사용한다.
  List<Widget> buildSlivers(BuildContext context) {
    // Remove unused cs
    final tick =
        context.select<TagFilterProvider, int>((p) => p.resultsVersion);
    final loading = context.select<TagFilterProvider, bool>((p) => p.isLoading);

    return [
      // ✅ 헤더는 고정 (애니메이션 X)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            '클립',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),

      // ✅ 로딩 시엔 스켈레톤만
      if (loading)
        const _SkeletonSliver()
      else if (items.isEmpty)
        const SliverFillRemaining(
          child: Center(child: Text('아직 등록된 클립이 없어요.')),
        )
      else
        // ✅ 데이터일 때만 리스트 렌더
        SliverList.separated(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final clip = item.clip;
            final dur = _fmtMs(clip.durationMs);
            final swipeKey = GlobalKey<SwipeActionTileState>();

            ImageProvider? thumbProvider;
            if (item.thumbnail != null) {
              thumbProvider = MemoryImage(item.thumbnail!);
            } else if (resolveThumb != null) {
              thumbProvider = resolveThumb!(item);
            }
            final storageChip = _buildStorageChip(ctx, clip.storageMode);

            // ⬇️ 여기서 아이템만 애니메이션 적용
            return _FadeSlideIn(
              index: i,
              version: tick, // 태그 결과 바뀔 때만 애니 시작
              child: selectionMode
                  ? _SelectableClipTile(
                      imageProvider: thumbProvider,
                      duration: dur,
                      title: clip.title,
                      storageChip: storageChip,
                      tags: item.tags,
                      selected: selectedClipIds.contains(clip.id),
                      onTap: onToggleSelection == null
                          ? null
                          : () => onToggleSelection!(item),
                    )
                  : SwipeActionTile(
                      key: swipeKey,
                      actionWidth: 300,
                      actions: [
                        _buildSwipeAction(
                          color: AppColors.info,
                          icon: Icons.edit_rounded,
                          label: '편집',
                          onTap: () async {
                            final clipProvider = context.read<ClipProvider>();
                            final currentCollection =
                                clipProvider.selectedCollectionId == null
                                    ? null
                                    : clipProvider.collections
                                        .cast<dynamic>()
                                        .firstWhere(
                                          (c) =>
                                              (c.id as int) ==
                                              clipProvider.selectedCollectionId,
                                          orElse: () => null,
                                        );
                            final collectionName =
                                currentCollection?.name as String?;
                            final ok = await context.push<bool>(
                              '${AppRoutes.clipsPath}/${AppRoutes.clipsEditPath}?clipId=${clip.id}'
                              '${collectionName != null ? '&collectionName=${Uri.encodeComponent(collectionName)}' : ''}',
                            );
                            if (ok == true && context.mounted) {
                              clipProvider.backToCollections();
                              clipProvider.loadCollections();
                            }
                          },
                        ),
                        _buildSwipeAction(
                          color: AppColors.warning,
                          icon: Icons.swap_horiz_rounded,
                          label: '전환',
                          onTap: () => _showStorageModeSheet(
                            context,
                            item,
                            onApplied: () => swipeKey.currentState?.close(),
                          ),
                        ),
                        _buildSwipeAction(
                          color: AppColors.danger,
                          icon: Icons.delete_rounded,
                          label: '삭제',
                          onTap: () => _confirmDeleteClip(context, item),
                        ),
                      ],
                      child: InkWell(
                        onTap: () => onOpen(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EpisodeThumbnail(
                                  imageProvider: thumbProvider, duration: dur),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clip.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (storageChip != null) storageChip,
                                        for (final t in item.tags.take(4))
                                          MiniChip(label: t.name),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          },
          separatorBuilder: selectionMode
              ? (_, __) => const SizedBox.shrink()
              : (ctx, __) => Divider(
                    height: 1,
                    color: Theme.of(ctx)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.6),
                  ),
        ),

      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }
}

class _SelectableClipTile extends StatelessWidget {
  const _SelectableClipTile({
    required this.imageProvider,
    required this.duration,
    required this.title,
    required this.storageChip,
    required this.tags,
    required this.selected,
    required this.onTap,
  });

  final ImageProvider<Object>? imageProvider;
  final String duration;
  final String title;
  final Widget? storageChip;
  final List<dynamic> tags;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final toggleSelection = onTap;
    final selectedColor = cs.primaryContainer.withValues(alpha: 0.65);

    return Material(
      color: selected ? selectedColor : cs.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged:
                    toggleSelection == null ? null : (_) => toggleSelection(),
              ),
              const SizedBox(width: 2),
              EpisodeThumbnail(
                  imageProvider: imageProvider, duration: duration),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (storageChip != null) storageChip!,
                          for (final t in tags.take(4)) MiniChip(label: t.name),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({
    required this.child,
    required this.index,
    required this.version, // 태그 결과 버전 (변경될 때만 애니 트리거)
  });

  final Widget child;
  final int index;
  final int version;

  @override
  Widget build(BuildContext context) {
    // version 이 바뀌면 Key가 달라져서 새 애니메이션 시작
    return TweenAnimationBuilder<double>(
      key: ValueKey('ani_${version}_$index'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 10),
          child: child,
        ),
      ),
    );
  }
}

class _LineSkeleton extends StatelessWidget {
  const _LineSkeleton();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return Container(
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}

class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver();

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: 8,
      itemBuilder: (_, __) => const _LineSkeleton(),
    );
  }
}
