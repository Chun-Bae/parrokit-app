import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:parrokit/core/content/study_file_name.dart';
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
import 'package:parrokit/core/shared/utils/format_bytes.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/content/study_data_transfer.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import '../widgets/backup_parts_sheet.dart';
import '../widgets/backup_progress_dialog.dart';
import '../widgets/nav_tile.dart';
import 'remote_storage_section.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 임시 파일을 다 지웠을 때.
const String cacheClearedMessage = '임시 파일을 정리했어요.';

/// 쓰는 중인 것이 남았을 때. 무엇도 안 지워졌는데 '정리했어요'만 뜨면
/// 용량이 그대로인 것을 보고 고장으로 여긴다(5차 566).
const String cacheClearPartialMessage = '쓰는 중인 파일은 남겨 뒀어요.';

class DataSection extends StatefulWidget {
  const DataSection({super.key});

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  bool _clearingCache = false;

  /// 지금 보여 줄 임시 파일 크기. 잰 값은 CacheService가 들고 있다.
  String get _cacheSize {
    final bytes = CacheService.instance.sizeBytes.value;
    return bytes == null ? '' : formatBytes(bytes);
  }

  void _onCacheSizeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    CacheService.instance.sizeBytes.addListener(_onCacheSizeChanged);
    _refreshCache();
    // 캐시 관리 화면을 한 번 열어야만 숫자가 최신으로 보이던 문제 — 이
    // 카드가 보이는 시점에 바로 최신 값을 받아오도록 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ClipProvider>().refreshStorageUsage();
    });
  }

  /// 다시 재게 한다. 잰 값은 CacheService가 들고 있어 저장 용량 시트와
  /// 늘 같다(5차 477, 565). 전에는 각자 재서 숫자가 어긋났다.
  Future<void> _refreshCache() => CacheService.instance.getCacheSize();

  @override
  void dispose() {
    CacheService.instance.sizeBytes.removeListener(_onCacheSizeChanged);
    super.dispose();
  }

  /// 무엇을 담거나 되돌릴지 먼저 고르고(5차 345, 사용자 요청) 진행한다.
  Future<void> _runBackup(BackupDialogType type) async {
    final restoring = type == BackupDialogType.restore;
    final parts = await showBackupPartsSheet(context, restoring: restoring);
    if (parts == null || !mounted) return;

    final accountId = context.read<UserProvider?>()?.currentUser?.id ?? 'guest';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackupProgressDialog(
        type: type,
        parts: parts,
        onStart: (onProgress) => restoring
            ? BackupService.instance.restoreBackup(
                onProgress: onProgress, only: parts, accountId: accountId)
            : BackupService.instance.createBackup(
                onProgress: onProgress, parts: parts, accountId: accountId),
      ),
    );
    if (!mounted || !restoring) return;
    // 클립만 되돌리면 앱이 다시 켜져서 토스트가 보이지 않는다. 그래서
    // 문장·단어를 고른 경우에만 알린다.
    //
    // 하나도 안 들어왔을 때도 말한다(5차). 전에는 0개면 입을 다물어서
    // 화면에 '다 불러왔어요.'만 남았다 - 백업에 있던 문장이 모두 이미
    // 있는 것이라 한 개도 더해지지 않았는데, 사용자는 다 들어온 줄 알고
    // 백업 파일을 지운다. studyRestoreSummary는 그 말('새로 들어온 문장과
    // 단어는 없어요.')을 이미 갖고 있고, 문장·단어 파일 불러오기 쪽은
    // 조건 없이 그대로 보여 준다. 한 흐름이 두 가지로 굴지 않게 맞춘다.
    if (parts.sentences || parts.words) {
      showToast(studyRestoreSummary(BackupService.instance.lastStudyRestore));
    }
  }

  /// 문장·단어를 파일로 주고받는다(사용자 요청 2026-11-17).
  ///
  /// 전에는 보관함 문장 탭의 ⋮ 메뉴에만 있었고 단어는 아예 없었다.
  /// 백업은 클립까지 담는 큰 일이라, 글만 주고받고 싶을 때 쓴다.
  Future<void> _openStudyTransferSheet() async {
    final choice = await showAppSheet<String>(
      context: context,
      fullHeight: false,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('문장·단어 주고받기', style: context.texts.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '내 문장과 단어를 파일 하나로 내보내고, 그 파일에서 다시 불러와요. '
                '클립과 영상은 백업으로 담아요.',
                style: context.texts.bodyMedium,
              ),
            ),
            ListTile(
              key: const ValueKey('study-export'),
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('파일로 내보내기'),
              onTap: () => Navigator.pop(sheetContext, 'export'),
            ),
            ListTile(
              key: const ValueKey('study-import'),
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('파일에서 불러오기'),
              subtitle: const Text('이미 있는 문장·단어는 건너뛰어요'),
              onTap: () => Navigator.pop(sheetContext, 'import'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'export') {
      await _exportStudyFile();
    } else {
      await _importStudyFile();
    }
  }

  String get _accountId =>
      context.read<UserProvider?>()?.currentUser?.id ?? 'guest';

  Future<void> _exportStudyFile() async {
    try {
      final json = await exportStudyData(_accountId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${studyFileName(DateTime.now())}');
      await file.writeAsString(json);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        title: 'Parrokit 문장·단어',
      ));
    } catch (_) {
      if (mounted) showToast('문장·단어를 내보내지 못했어요. 다시 시도해 주세요.');
    }
  }

  Future<void> _importStudyFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = picked?.files.single.path;
      if (path == null) return; // 고르지 않고 닫았다
      final source = await File(path).readAsString();
      final count = await importStudyData(_accountId, source);
      if (!mounted) return;
      showToast(studyRestoreSummary(count));
    } catch (e) {
      if (!mounted) return;
      // 읽을 수 없는 파일은 까닭을 그대로 알린다(5차). 전에는 '다시 시도해
      // 주세요'만 떴는데, 엉뚱한 파일을 고른 것이라 다시 해도 똑같다.
      final unreadable = e.toString().contains(studyFileUnreadableMessage);
      showToast(unreadable
          ? studyFileUnreadableMessage
          : '문장·단어를 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }

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
    // 지운 뒤 남은 양을 그대로 돌려준다. 안에서 이미 다시 쟀다.
    final left = await CacheService.instance.clearCache();
    if (!mounted) return;
    setState(() => _clearingCache = false);
    // 다 못 지웠는데 '정리했어요'만 띄우면, 용량이 그대로인 것을 보고
    // 고장으로 여긴다(5차 566).
    showToast(left > 0 ? cacheClearPartialMessage : cacheClearedMessage);
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
                // 화면 제목과 같은 말로 둔다(5차). '보관 영상'은 보관함
                // 영상과 헷갈렸고, 여는 화면은 '기기 보관 관리'였다.
                label: '받아 둔 영상',
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
            icon: Icons.swap_horiz_rounded,
            title: '문장·단어 주고받기',
            subtitle: '파일로 내보내고 파일에서 불러와요',
            onTap: _openStudyTransferSheet,
          ),
          const SizedBox(height: 4),
          NavTile(
            icon: Icons.cloud_outlined,
            // Google Drive는 더 쓰지 않으므로 제목에서 뺐다(5차). 아직 연동이
            // 남아 있는 사람에게만 오른쪽에 그 사실을 적는다.
            title: '저장 용량',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (driveLinked)
                  Text(
                    'Drive 연동됨',
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
