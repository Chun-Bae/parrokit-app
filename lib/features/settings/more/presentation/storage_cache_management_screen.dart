import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:parrokit/features/collection/shell/presentation/collection_shell_screen.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/format_bytes.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/card_container.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 받아 둔 영상이 하나도 없을 때. 무엇을 하면 생기는지와 갈 길을 준다.
/// 이 화면의 이름. 들어오는 칸(더보기 '받아 둔 영상')·앱바·맨 위 카드가
/// 한 말을 쓴다(5차 497).
const String cachedScreenTitle = '받아 둔 영상';

const String cachedEmptyTitle = '받아 둔 영상이 아직 없어요';
const String cachedEmptyBody =
    '서버에 둔 영상을 한 번 보면 이 기기에 받아 둬요. 그다음부터는 인터넷이 없어도 열려요.';
const String cachedEmptyActionLabel = '보관함 열기';

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
    } catch (e, stack) {
      // 내부 오류 글을 그대로 보여 주지 않는다(5차). 사람 말로 안내하고
      // 자세한 것은 로그로 남긴다.
      AppLogger.e('기기 보관 목록 불러오기 실패', error: e, stackTrace: stack);
      if (!mounted) return;
      setState(() {
        _error = '목록을 불러오지 못했어요. 아래로 당겨 다시 해 주세요.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
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
    if (storageMode == ClipStorageConstants.storageModeServer) {
      return cs.secondary;
    }
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
          // 줄 버튼 '기기에서 지우기'와 같은 말로(5차). 예전 '기기 보관분 삭제'.
          '기기에서 지울까요?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '원본은 그대로 있고, 기기에 받아 둔 파일만 지워요. 다음에 볼 때 다시 받아요.',
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
            key: const ValueKey('clear-clip-cache-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기'),
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
      showToast('기기에서 지웠어요.');
    } else {
      showToast(deleteFailedShortMessage);
    }
  }

  Widget _buildTopSummary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 더보기 '받아 둔 영상 N개 · N MB'와 같은 값을 쓴다(5차 363). 전에는 이
    // 화면만 클립 원본 크기를 더해서 두 곳의 용량이 달라 보였다.
    final usedBytes =
        context.watch<ClipProvider>().cachedRemoteStorageUsedBytes;

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
                  // 화면 제목·더보기 칸과 같은 말로(5차 497). 들어올 때는
                  // '받아 둔 영상'인데 맨 위 카드만 '파일'이라 불렀다.
                  // 아래 설명문은 원본과 견주는 자리라 '받아 둔 파일' 그대로.
                  cachedScreenTitle,
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
          // 지울 것이 없는데 지우기 설명부터 하지 않는다(5차 451).
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '원본은 그대로 두고, 기기에 받아 둔 파일만 지워요. '
              '이 기기에만 있는 클립은 여기 없어요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            // '보관 용량'은 저장 용량 시트의 '보관한 영상'(이 기기에 둔 클립
            // 원본)과 헷갈렸다. 여기 숫자는 받아 둔 것만 센다(5차 497).
            '받아 둔 용량: ${formatBytes(usedBytes)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
                borderRadius: BorderRadius.circular(AppRadius.md),
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
                          label: formatBytes(item.clip.storageBytes),
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
                  // '캐시'는 앱 안쪽 말이라 무엇이 지워지는지 알기 어려웠다(5차).
                  label: const Text('기기에서 지우기'),
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
        // 들어온 줄('받아 둔 영상')과 같은 말(5차).
        title: const Text(cachedScreenTitle),
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
              // 위 카드와 같은 말을 분홍 상자로 한 번 더 하던 안내는 뺐다(5차).
              // '로컬 클립은 여기 없다'는 말은 위 카드 설명에 합쳤다.
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
                // 전에는 '아직 없어요.' 한 줄뿐이라, 어떻게 하면 생기는지도
                // 어디로 가야 하는지도 알 수 없었다(5차 451).
                CardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cachedEmptyTitle,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cachedEmptyBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          key: const ValueKey('cached-empty-open-library'),
                          onPressed: () {
                            // 영상 이야기를 하고 보내므로 클립 탭으로 연다.
                            // 그냥 보내면 마지막에 본 탭(단어 등)이 열렸다(5차 451).
                            CollectionShellScreen.openTab(CollectionShellScreen.clipTab);
                            context.go(AppRoutes.collectionPath);
                          },
                          child: const Text(cachedEmptyActionLabel),
                        ),
                      ),
                    ],
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
        borderRadius: BorderRadius.circular(AppRadius.full),
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
