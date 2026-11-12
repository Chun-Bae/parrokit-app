// 보관함 클립 탭의 새 화면 (개편 1단계, .claude/clip-redesign.md).
//
// 전에는 저장 위치(로컬/서버/클라우드) → 보기 방식 → 그룹 → 컬렉션 → 클립을
// 차례로 골라야 영상에 닿았다. 여기서는 위치를 고르지 않는다. 모든 위치의
// 클립을 한 목록으로 보여주고, 위치와 태그는 필터 칩으로 거른다. 컬렉션은
// "폴더"로 보여주고, 위치가 달라도 이름이 같으면 한 폴더로 합친다.
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
import 'widgets/clip_list_view.dart';

/// 이름으로 합친 폴더. 위치마다 있던 컬렉션 id를 모두 들고 있다.
class _Folder {
  _Folder(this.name);
  final String name;
  final Set<int> collectionIds = {};
  int count = 0;
}

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
  List<_Folder> _folders = [];
  bool _loading = true;
  bool _loadingNow = false;
  bool _reloadAgain = false;

  /// 위치 필터: '전체' 또는 storageMode. 태그 필터는 이름.
  String _location = _all;
  String? _tag;
  _Folder? _openFolder;

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

      final byName = <String, _Folder>{};
      final folderOfCollection = <int, _Folder>{};
      for (final collection in collectionLists.expand((c) => c)) {
        final name = collection.name.trim();
        if (name.isEmpty) continue;
        final folder = byName.putIfAbsent(name, () => _Folder(name));
        folder.collectionIds.add(collection.id);
        folderOfCollection[collection.id] = folder;
      }
      for (final item in clips) {
        final id = item.clip.collectionId;
        if (id != null) folderOfCollection[id]?.count++;
      }
      final folders = byName.values.where((f) => f.count > 0).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() {
        _clips = clips;
        _folders = folders;
        _loading = false;
        if (_openFolder != null) {
          _openFolder = byName[_openFolder!.name];
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
      if (_openFolder != null)
        SliverToBoxAdapter(child: _folderHeader(context, _openFolder!))
      else ...[
        if (recents.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionTitle(context, '이어보기')),
          SliverToBoxAdapter(child: _recentRow(context, recents)),
        ],
        if (_folders.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionTitle(context, '폴더')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                for (final folder in _folders) _folderTile(context, folder),
              ],
            ),
          ),
        ],
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

  Widget _sectionTitle(BuildContext context, String text, {String? trailing}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: context.texts.titleMedium.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null)
            Text(trailing,
                style: context.texts.labelMedium
                    .copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

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

  Widget _folderTile(BuildContext context, _Folder folder) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => setState(() {
          _openFolder = folder;
          _tag = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.folder_rounded,
                  size: 22, color: context.tokens.primary),
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
                    Text('${folder.count}개',
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

  Widget _folderHeader(BuildContext context, _Folder folder) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '모든 클립으로',
            onPressed: () => setState(() {
              _openFolder = null;
              _tag = null;
            }),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Icon(Icons.folder_rounded, size: 22, color: context.tokens.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleLarge.copyWith(color: cs.onSurface)),
          ),
          Text('${folder.count}개',
              style: context.texts.labelMedium
                  .copyWith(color: cs.onSurfaceVariant)),
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
