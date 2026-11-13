// 보관함 클립 탭의 새 화면 (개편 1단계, .claude/clip-redesign.md).
//
// 전에는 저장 위치(로컬/서버/클라우드) → 보기 방식 → 그룹 → 컬렉션 → 클립을
// 차례로 골라야 영상에 닿았다. 여기서는 위치를 고르지 않는다. 모든 위치의
// 클립을 한 목록으로 보여주고, 위치와 태그는 필터 칩으로 거른다. 컬렉션은
// "폴더"로 보여주고, 위치가 달라도 이름이 같으면 한 폴더로 합친다.
//
// 폴더 안에 폴더를 둘 수 있다. 이름에 '/'를 넣은 경로로 나타낸다(folder_tree.dart).
//
// 데이터는 바꾸지 않는다. 예전 화면은 그대로 있고, 더보기 > 앱 >
// "새 클립 화면"을 끄면 돌아간다(AppConfig.newClipLibrary).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'folder_picker_sheet.dart';
import 'folder_tree.dart';
import 'widgets/clip_list_view.dart';

class ClipLibraryHome extends StatefulWidget {
  const ClipLibraryHome({super.key});

  @override
  State<ClipLibraryHome> createState() => _ClipLibraryHomeState();
}

class _ClipLibraryHomeState extends State<ClipLibraryHome>
    with AutomaticKeepAliveClientMixin {
  /// 보관함 탭을 옆으로 넘겼다 돌아올 때마다 새로 만들어지며 로딩 표시가
  /// 깜빡였다. 화면을 살려 둔다.
  @override
  bool get wantKeepAlive => true;

  static const _all = '전체';

  List<ClipItem> _clips = [];
  /// 맨 위 폴더들.
  List<ClipFolder> _folders = [];
  Map<String, ClipFolder> _byPath = {};
  bool _loading = true;
  bool _loadingNow = false;
  bool _reloadAgain = false;

  /// 위치 필터: '전체' 또는 storageMode. 태그 필터는 이름.
  String _location = _all;
  String? _tag;
  ClipFolder? _openFolder;

  Timer? _debounce;
  ClipProvider? _clipProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _clipProvider = context.read<ClipProvider>()
        ..addListener(_onClipsMaybeChanged);
      _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clipProvider?.removeListener(_onClipsMaybeChanged);
    super.dispose();
  }

  /// 옮기기·삭제·편집 뒤 ClipProvider가 알린다. 몰려 오므로 한 번으로 모은다.
  void _onClipsMaybeChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  /// 불러올 위치. Drive 연동 여부는 앱이 켜진 뒤 늦게 정해지기도 해서 보지
  /// 않는다. 연동이 안 됐으면 Drive 클립은 가시성 필터에서 빠진다.
  List<String> get _fetchModes => [
        ClipStorageConstants.storageModeLocal,
        if (!ClipStorageConstants.isServerStorageLockedForCurrentUser())
          ClipStorageConstants.storageModeServer,
        ClipStorageConstants.storageModeGoogleDrive,
      ];

  /// 칩으로 보여줄 위치. 클립이 있거나 Drive가 연동된 위치만.
  List<String> _chipModes(ClipProvider provider) => [
        for (final mode in _fetchModes)
          if (mode == ClipStorageConstants.storageModeLocal ||
              _clips.any((c) => c.clip.storageMode == mode) ||
              (mode == ClipStorageConstants.storageModeGoogleDrive &&
                  provider.hasGoogleDriveLinked))
            mode,
      ];

  Future<void> _load() async {
    if (_loadingNow) {
      _reloadAgain = true;
      return;
    }
    final provider = _clipProvider ?? context.read<ClipProvider>();
    _loadingNow = true;
    try {
      final modes = _fetchModes;
      final clipLists =
          await Future.wait(modes.map(provider.fetchClipItemsByStorageMode));
      final collectionLists =
          await Future.wait(modes.map(provider.fetchVisibleCollectionsFor));
      final clips = [for (final list in clipLists) ...list]
        ..sort((a, b) => b.clip.id.compareTo(a.clip.id));

      final counts = <int, int>{};
      for (final item in clips) {
        final id = item.clip.collectionId;
        if (id != null) counts[id] = (counts[id] ?? 0) + 1;
      }
      final (folders, byPath) = buildFolderTree(
        [
          for (final c in collectionLists.expand((c) => c)) (c.id, c.name),
        ],
        counts,
        // '새 폴더'로 만든 빈 폴더도 보인다(5차).
        keepEmpty: true,
      );

      if (!mounted) return;
      setState(() {
        _clips = clips;
        _folders = folders;
        _byPath = byPath;
        _loading = false;
        if (_openFolder != null) {
          // 클립을 옮기거나 지워 폴더가 사라졌으면 남아 있는 가장 가까운 위로 간다.
          ClipFolder? next;
          for (var path = _openFolder!.path;
              path.isNotEmpty && next == null;
              path = path.contains('/')
                  ? path.substring(0, path.lastIndexOf('/'))
                  : '') {
            next = byPath[path];
          }
          _openFolder = next;
        }
        if (_location != _all && !modes.contains(_location)) _location = _all;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _loadingNow = false;
      if (_reloadAgain) {
        _reloadAgain = false;
        unawaited(_load());
      }
    }
  }

  Future<void> _refresh() async {
    final provider = context.read<ClipProvider>();
    await Future.wait([
      if (!ClipStorageConstants.isServerStorageLockedForCurrentUser())
        provider.pullRemoteServerClips(),
      if (provider.hasGoogleDriveLinked) provider.pullRemoteCloudClips(),
    ].map((f) => f.catchError((_) => 0)));
    await _load();
  }

  List<ClipItem> get _filtered => _clips.where((item) {
        if (_openFolder != null &&
            !_openFolder!.collectionIds.contains(item.clip.collectionId)) {
          return false;
        }
        if (_location != _all && item.clip.storageMode != _location) {
          return false;
        }
        if (_tag != null && !item.tags.any((t) => t.name == _tag)) return false;
        return true;
      }).toList();

  void _openClip(int clipId) => context.push(
        '${AppRoutes.clipsPath}/${AppRoutes.clipsPlayPath}?clipId=$clipId',
      );

  void _enterFolder(ClipFolder? folder) => setState(() {
        _openFolder = folder;
        _tag = null;
      });

  /// 클립 만들기 화면을 [path] 폴더로 열어 둔다. 폴더는 첫 클립을 저장할 때 생긴다
  /// (빈 컬렉션은 앱이 정리하므로 빈 폴더를 따로 저장하지 않는다).
  void _createClipIn(String path) => context.push(
        '${AppRoutes.clipsPath}/${AppRoutes.clipsCreatePath}'
        '?collectionName=${Uri.encodeComponent(path)}',
      );

  /// 열린 폴더의 이름 바꾸기·지우기.
  Future<void> _manageFolder(ClipFolder folder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const ValueKey('folder-rename'),
            leading: const Icon(Icons.drive_file_rename_outline_rounded),
            title: const Text('이름 바꾸기'),
            subtitle: folder.children.isEmpty
                ? null
                : const Text('안의 폴더도 함께 옮겨져요'),
            onTap: () => Navigator.pop(sheetContext, 'rename'),
          ),
          ListTile(
            key: const ValueKey('folder-delete'),
            // 클립이 있어 못 지울 때는 빨간색 대신 흐리게 둔다.
            leading: Icon(Icons.delete_outline_rounded,
                color: folder.totalCount == 0
                    ? Theme.of(sheetContext).colorScheme.error
                    : null),
            title: Text('폴더 지우기',
                style: folder.totalCount == 0
                    ? TextStyle(
                        color: Theme.of(sheetContext).colorScheme.error)
                    : null),
            subtitle: Text(folder.totalCount == 0
                ? '빈 폴더예요'
                : '클립 ${folder.totalCount}개를 먼저 옮기거나 지워야 해요'),
            enabled: folder.totalCount == 0,
            onTap: () => Navigator.pop(sheetContext, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    final provider = _clipProvider ?? context.read<ClipProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'rename') {
      final name =
          await showRenameFolderDialog(context, currentName: folder.name);
      if (!mounted || name == null) return;
      final parent = folder.parent;
      final newPath =
          normalizeFolderPath(parent == null ? name : '${parent.path}/$name');
      if (_byPath.containsKey(newPath)) {
        messenger.showSnackBar(
            SnackBar(content: Text("'$name' 폴더가 이미 있어요.")));
        return;
      }
      try {
        await provider.renameFolderPath(folder.path, newPath);
      } catch (_) {
        messenger.showSnackBar(const SnackBar(
            content: Text('이름을 바꾸지 못했어요. 다시 시도해 주세요.')));
        return;
      }
      await _load();
      if (!mounted) return;
      setState(() => _openFolder = _byPath[newPath]);
      messenger.showSnackBar(SnackBar(content: Text("'$name'(으)로 바꿨어요.")));
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text("'${folder.name}' 폴더를 지울까요?"),
          content: const Text('빈 폴더라 클립은 지워지지 않아요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소')),
            FilledButton(
                key: const ValueKey('folder-delete-confirm'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('지우기')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final deleted = await provider.deleteEmptyFolderPath(folder.path);
      if (!mounted) return;
      if (!deleted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('폴더에 클립이 있어 지우지 않았어요.')));
        return;
      }
      setState(() => _openFolder = folder.parent);
      await _load();
      messenger.showSnackBar(
          SnackBar(content: Text("'${folder.name}' 폴더를 지웠어요.")));
    }
  }

  /// 지금 폴더 안(맨 위면 맨 위)에 새 폴더를 만든다. 예전엔 이름을 받은 뒤
  /// 클립 만들기로 넘어가 첫 클립을 저장해야 폴더가 생겼다(5차, 사용자 요청으로
  /// 폴더만 만든다). 폴더는 기기(로컬)에 만들고, 다른 위치의 클립도 같은 이름이면
  /// 이 폴더에 함께 보인다.
  Future<void> _newFolder() async {
    final parent = _openFolder;
    final name = await showNewFolderDialog(context,
        parentName: parent?.name, createsNow: true);
    if (!mounted || name == null) return;
    final path = normalizeFolderPath(
        parent == null ? name : '${parent.path}/$name');
    final messenger = ScaffoldMessenger.of(context);
    if (_byPath.containsKey(path)) {
      messenger.showSnackBar(
          SnackBar(content: Text("'$name' 폴더가 이미 있어요.")));
      return;
    }
    final provider = _clipProvider ?? context.read<ClipProvider>();
    try {
      await provider.libraryEntitySyncCoordinator
          .createCollection(path, ClipStorageConstants.storageModeLocal);
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('폴더를 만들지 못했어요. 다시 시도해 주세요.')));
      return;
    }
    await _load();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text("'$name' 폴더를 만들었어요.")));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<ClipProvider>();
    final recents = context.watch<ClipActivityProvider>().recent6;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filtered;
    final tags = {
      for (final item in _clips)
        if (_openFolder == null ||
            _openFolder!.collectionIds.contains(item.clip.collectionId))
          for (final tag in item.tags) tag.name,
    }.toList()
      ..sort();

    final slivers = <Widget>[
      if (_openFolder != null) ...[
        SliverToBoxAdapter(child: _folderHeader(context, _openFolder!)),
        ..._folderGrid(context, _openFolder!.children),
        SliverToBoxAdapter(
          child: _sectionTitle(context, '이 폴더의 클립',
              trailing: '${_openFolder!.directCount}개'),
        ),
      ] else ...[
        if (recents.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionTitle(context, '이어보기')),
          SliverToBoxAdapter(child: _recentRow(context, recents)),
        ],
        ..._folderGrid(context, _folders),
        SliverToBoxAdapter(
          child: _sectionTitle(context, '모든 클립', trailing: '${_clips.length}개'),
        ),
      ],
      SliverToBoxAdapter(
        child: _filterChips(context, provider, tags),
      ),
      ...ClipListView(
        items: items,
        showHeader: false,
        onOpen: (ci) => _openClip(ci.clip.id),
      ).buildSlivers(context),
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text,
      {String? trailing, Widget? action}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, action == null ? 18 : 8, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: context.texts.titleMedium.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(trailing,
                  style: context.texts.labelMedium
                      .copyWith(color: cs.onSurfaceVariant)),
            ),
          if (action != null) action,
        ],
      ),
    );
  }

  /// '폴더' 제목 + 새 폴더 버튼 + 폴더 칸. 맨 위와 폴더 안에서 같이 쓴다.
  List<Widget> _folderGrid(BuildContext context, List<ClipFolder> folders) => [
        SliverToBoxAdapter(
          child: _sectionTitle(
            context,
            '폴더',
            action: TextButton.icon(
              key: const ValueKey('new-clip-folder'),
              onPressed: _newFolder,
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('새 폴더'),
            ),
          ),
        ),
        if (folders.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                for (final folder in folders) _folderTile(context, folder),
              ],
            ),
          ),
      ];

  Widget _recentRow(
    BuildContext context,
    List<(int, Uint8List?, String?, String?)> recents,
  ) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: recents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final (clipId, thumb, title, _) = recents[index];
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _openClip(clipId),
            child: SizedBox(
              width: 144,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: thumb != null
                          ? Image.memory(thumb, fit: BoxFit.cover)
                          : Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.play_arrow_rounded,
                                  color: cs.onSurfaceVariant),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        context.texts.labelMedium.copyWith(color: cs.onSurface),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _folderTile(BuildContext context, ClipFolder folder) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _enterFolder(folder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                  folder.children.isEmpty
                      ? Icons.folder_rounded
                      : Icons.folder_copy_rounded,
                  size: 22,
                  color: context.tokens.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.labelLarge.copyWith(
                            color: cs.onSurface, fontWeight: FontWeight.w700)),
                    Text(
                        folder.children.isEmpty
                            ? '${folder.totalCount}개'
                            : '${folder.totalCount}개 · 폴더 ${folder.children.length}',
                        style: context.texts.labelSmall
                            .copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderHeader(BuildContext context, ClipFolder folder) {
    final cs = Theme.of(context).colorScheme;
    final trail = folder.trail;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 한 단계 위로. 맨 위 폴더면 모든 클립으로.
              IconButton(
                key: const ValueKey('folder-up'),
                tooltip: folder.parent == null
                    ? '모든 클립으로'
                    : '${folder.parent!.name}(으)로',
                onPressed: () => _enterFolder(folder.parent),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Icon(Icons.folder_open_rounded,
                  size: 22, color: context.tokens.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        context.texts.titleLarge.copyWith(color: cs.onSurface)),
              ),
              IconButton(
                key: const ValueKey('folder-add-clip'),
                tooltip: '이 폴더에 클립 추가',
                onPressed: () => _createClipIn(folder.path),
                icon: const Icon(Icons.video_call_outlined),
              ),
              // 새 보관함에는 폴더 이름 바꾸기·지우기가 없어 예전 화면으로
              // 돌아가야 했다(5차).
              IconButton(
                key: const ValueKey('folder-manage'),
                tooltip: '폴더 관리',
                onPressed: () => _manageFolder(folder),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          // 폴더 안의 폴더면 경로를 보여주고, 누르면 그 단계로 간다.
          if (trail.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12),
              child: Row(children: [
                InkWell(
                  onTap: () => _enterFolder(null),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text('클립',
                        style: context.texts.labelMedium
                            .copyWith(color: cs.onSurfaceVariant)),
                  ),
                ),
                for (final step in trail) ...[
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: cs.onSurfaceVariant),
                  InkWell(
                    onTap: step == folder ? null : () => _enterFolder(step),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Text(step.name,
                          style: context.texts.labelMedium.copyWith(
                              color: step == folder
                                  ? cs.onSurface
                                  : context.tokens.primary,
                              fontWeight: step == folder
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  Widget _filterChips(
    BuildContext context,
    ClipProvider provider,
    List<String> tags,
  ) {
    final modes = _chipModes(provider);
    String label(String mode) => switch (mode) {
          ClipStorageConstants.storageModeLocal => '로컬',
          ClipStorageConstants.storageModeServer => '서버',
          ClipStorageConstants.storageModeGoogleDrive => '클라우드',
          _ => mode,
        };
    Widget chip(String text, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(text),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onTap(),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        children: [
          chip(_all, _location == _all && _tag == null, () {
            setState(() {
              _location = _all;
              _tag = null;
            });
          }),
          if (modes.length > 1)
            for (final mode in modes)
              chip(
                  label(mode),
                  _location == mode,
                  () => setState(
                      () => _location = _location == mode ? _all : mode)),
          for (final tag in tags)
            chip('#$tag', _tag == tag,
                () => setState(() => _tag = _tag == tag ? null : tag)),
        ],
      ),
    );
  }
}
