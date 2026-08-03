import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/card_container.dart';

class StorageCacheManagementScreen extends StatefulWidget {
  const StorageCacheManagementScreen({super.key});

  @override
  State<StorageCacheManagementScreen> createState() =>
      _StorageCacheManagementScreenState();
}

class _StorageCacheManagementScreenState
    extends State<StorageCacheManagementScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  List<ClipItem> _items = [];
  final Set<int> _deletingIds = {};
  bool _didLoadOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadOnce) return;
    _didLoadOnce = true;
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = _items.isEmpty;
        _isRefreshing = true;
        _error = null;
      });
    }

    try {
      final provider = context.read<ClipProvider>();
      final items = await provider.fetchCachedRemoteClipItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _isLoading = false;
        _isRefreshing = false;
      });
      await provider.refreshStorageUsage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

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

  String _storageLabel(String storageMode) {
    if (storageMode == ClipStorageConstants.storageModeServer) return '서버';
    if (storageMode == ClipStorageConstants.storageModeGoogleDrive) {
      return 'Google Drive';
    }
    return '원격';
  }

  Color _storageColor(BuildContext context, String storageMode) {
    final cs = Theme.of(context).colorScheme;
    if (storageMode == ClipStorageConstants.storageModeServer) return cs.secondary;
    if (storageMode == ClipStorageConstants.storageModeGoogleDrive) {
      return cs.tertiary;
    }
    return cs.primary;
  }

  Future<void> _clearCache(ClipItem item) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '기기 보관분 삭제',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '이 클립은 원격 저장본은 유지한 채, 기기 안의 보관 파일만 지웁니다.\n\n로컬 저장본은 이 화면에서 삭제되지 않습니다.',
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _deletingIds.add(item.clip.id));

    final success = await context.read<ClipProvider>().clearRemoteClipCache(
          item.clip.id,
        );

    if (!mounted) return;
    setState(() => _deletingIds.remove(item.clip.id));

    if (success) {
      await _load(showSpinner: false);
      if (!mounted) return;
      showToast('기기 보관분을 삭제했어요.');
    } else {
      showToast('삭제하지 못했어요.');
    }
  }

  Widget _buildTopSummary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final usedBytes = _items.fold<int>(
      0,
      (total, item) => total + item.clip.storageBytes,
    );

    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '원격 저장 클립의 기기 보관분',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                '${_items.length}개',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '여기서는 서버나 Google Drive에 있는 원본은 그대로 두고, 기기 안의 보관 파일만 지울 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '보관 용량: ${_formatBytes(usedBytes)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.2)),
      ),
      child: Text(
        '로컬 저장본은 표시되지 않습니다. 이 화면은 원격 클립의 기기 보관분만 정리합니다.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, ClipItem item) {
    final cs = Theme.of(context).colorScheme;
    final label = _storageLabel(item.clip.storageMode);
    final color = _storageColor(context, item.clip.storageMode);
    final isDeleting = _deletingIds.contains(item.clip.id);

    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 72,
                  height: 72,
                  color: cs.surfaceContainerHighest,
                  child: item.thumbnail != null
                      ? Image.memory(
                          item.thumbnail!,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.play_circle_outline_rounded,
                          color: cs.onSurfaceVariant,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.clip.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(label: label, color: color),
                        _Badge(
                          label: _formatBytes(item.clip.storageBytes),
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : () => _clearCache(item),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('캐시 삭제'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('기기 보관 관리'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(showSpinner: false),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildTopSummary(context),
              const SizedBox(height: AppSpacing.md),
              _buildWarning(context),
              const SizedBox(height: AppSpacing.md),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                CardContainer(
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.error,
                    ),
                  ),
                )
              else if (_items.isEmpty)
                CardContainer(
                  child: Text(
                    '지울 수 있는 기기 보관분이 아직 없어요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ..._items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildItemCard(context, item),
                  ),
                ),
              if (_isRefreshing)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '목록을 다시 불러오는 중',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
