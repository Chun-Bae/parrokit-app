// 더보기의 "데이터" 카드. 백업·복원·기기 보관 영상·임시 파일을 아이콘 네 칸으로,
// 저장 용량과 Google Drive 연동은 그 아래 한 줄로 둔다.
//
// 전에는 백업, 저장 공간(설명 세 줄), 원격 저장소(펼치기), 임시 보관 파일이
// 각각 제목이 붙은 섹션이었다. 하는 일은 그대로이고 글만 줄였다.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/infrastructure/services/backup_service.dart';
import 'package:parrokit/core/infrastructure/services/cache_service.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import '../widgets/backup_progress_dialog.dart';
import '../widgets/nav_tile.dart';
import 'remote_storage_section.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

class DataSection extends StatefulWidget {
  const DataSection({super.key});

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  String _cacheSize = '';
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _refreshCache();
    // 캐시 관리 화면을 한 번 열어야만 숫자가 최신으로 보이던 문제 — 이
    // 카드가 보이는 시점에 바로 최신 값을 받아오도록 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ClipProvider>().refreshStorageUsage();
    });
  }

  Future<void> _refreshCache() async {
    final size = await CacheService.instance.getCacheSize();
    if (mounted) {
      setState(() => _cacheSize = CacheService.instance.formatSize(size));
    }
  }

  Future<void> _runBackup(BackupDialogType type) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BackupProgressDialog(
          type: type,
          onStart: (onProgress) => type == BackupDialogType.backup
              ? BackupService.instance.createBackup(onProgress: onProgress)
              : BackupService.instance.restoreBackup(onProgress: onProgress),
        ),
      );

  Future<void> _clearCache() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('임시 파일 정리'),
        content: Text(
          '앱이 잠깐 보관해 둔 파일을 지워요. 쓰는 동안 다시 생길 수 있어요.\n\n정리할 용량: $_cacheSize',
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
            key: const ValueKey('clear-cache-confirm'),
            onPressed: () => Navigator.pop(context, true),
            // 제목·완료 안내('정리했어요')와 같은 말로(5차). 예전 '삭제'.
            child: const Text('정리'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearingCache = true);
    // UX: 너무 빨리 끝나면 어색하므로 최소 지연
    await Future.delayed(const Duration(milliseconds: 500));
    await CacheService.instance.clearCache();
    await _refreshCache();
    if (!mounted) return;
    setState(() => _clearingCache = false);
    showToast('임시 파일을 정리했어요.');
  }

  void _openStorageSheet() {
    showAppSheet<void>(
      context: context,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text('저장 용량', style: context.texts.titleLarge),
            const SizedBox(height: 12),
            const RemoteStorageDetails(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    final cachedCount = clipProvider.cachedRemoteClipCount;
    final cachedBytes = clipProvider.cachedRemoteStorageUsedBytes;
    final driveLinked = clipProvider.hasGoogleDriveLinked;

    // 카드 테두리·그림자·여백 없이 목록으로 붙인다.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GridAction(
                icon: Icons.save_alt_rounded,
                label: '백업',
                onTap: () => _runBackup(BackupDialogType.backup),
              ),
              _GridAction(
                icon: Icons.settings_backup_restore_rounded,
                label: '불러오기',
                onTap: () => _runBackup(BackupDialogType.restore),
              ),
              _GridAction(
                icon: Icons.video_library_outlined,
                label: '보관 영상',
                caption: '$cachedCount개 · ${formatBytes(cachedBytes)}',
                onTap: () =>
                    context.pushNamed(AppRoutes.storageCacheManagement),
              ),
              _GridAction(
                icon: Icons.cleaning_services_outlined,
                label: '임시 파일',
                caption: _clearingCache ? '정리 중' : _cacheSize,
                onTap: _clearingCache ? null : _clearCache,
              ),
            ],
          ),
          const SizedBox(height: 4),
          NavTile(
            icon: Icons.cloud_outlined,
            title: '저장 용량 · Google Drive',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  driveLinked ? '연동됨' : '연동 안 됨',
                  style: context.texts.labelMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35),
                ),
              ],
            ),
            onTap: _openStorageSheet,
          ),
        ],
      ),
    );
  }
}

String formatBytes(int bytes) {
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

/// 아이콘 위, 이름 아래인 격자 한 칸. 필요하면 작은 숫자를 한 줄 더 붙인다.
class _GridAction extends StatelessWidget {
  const _GridAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 28, color: cs.onSurface.withValues(alpha: 0.8)),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // labelLarge는 버튼 글자용이라 색이 비어 있다. 직접 준다.
                style: context.texts.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (caption != null && caption!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
