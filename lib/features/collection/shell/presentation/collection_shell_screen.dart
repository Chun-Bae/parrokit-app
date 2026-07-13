import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart'; // Tag definition
import 'package:parrokit/features/collection/library/domain/library_mode.dart';
import 'package:parrokit/features/collection/library/presentation/providers/tag_filter_provider.dart';
import 'package:parrokit/features/collection/library/presentation/sections/library_folder_section.dart';
import 'package:parrokit/features/collection/library/presentation/sections/library_tag_section.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/bookmark_tabs.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/storage_scope_tabs.dart';
import 'widgets/collection_header_delegate.dart';

/// 콜렉션 메인 탭바 쉘 화면
///
/// 커뮤니티 화면과 동일하게, 바깥 앱바부터 그 아래 탭들(저장위치/유형별·
/// 태그별 보기)까지 하나의 [NestedScrollView] 헤더로 묶어 스크롤에 따라
/// 차근차근 접히도록 한다.
///
/// [LibraryScreen]은 딥링크 전용 라우트(`collectionClipPath`)에서 여전히
/// 단독으로 쓰이므로 건드리지 않고, 이 화면이 그 상태(저장위치/폴더-태그
/// 탭)를 직접 소유해 [LibraryFolderSection]/[LibraryTagSection]을 바로
/// 조립한다.
class CollectionShellScreen extends StatefulWidget {
  const CollectionShellScreen({super.key});

  @override
  State<CollectionShellScreen> createState() => _CollectionShellScreenState();
}

class _CollectionShellScreenState extends State<CollectionShellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _outerScrollController = ScrollController();

  LibraryTab _tab = LibraryTab.folder;
  String _storageMode = ClipStorageConstants.storageModeLocal;
  bool _headerVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _outerScrollController.addListener(_checkHeaderVisibility);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final clipProvider = context.read<ClipProvider>();
      final tagProv = context.read<TagFilterProvider>();

      await tagProv.startWatching();
      clipProvider.startWatchingDistinctTags();
      await clipProvider.setActiveStorageMode(_storageMode);
    });
  }

  void _handleTabChanged() {
    if (!mounted) return;
    setState(() {});

    if (_tabController.index != 0) {
      context.read<ClipProvider>().closeCollectionMenu();
    }
  }

  void _checkHeaderVisibility() {
    final fullyVisible = _outerScrollController.offset <= 1.0;
    if (_headerVisible == fullyVisible) return;
    setState(() => _headerVisible = fullyVisible);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _outerScrollController.removeListener(_checkHeaderVisibility);
    _outerScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onStorageModeChanged(String mode) {
    if (_storageMode == mode) return;
    setState(() => _storageMode = mode);
    context.read<ClipProvider>().setActiveStorageMode(mode);
  }

  void _onTagSelected(Tag t) =>
      context.read<TagFilterProvider>().addTag(t.name);

  void _onTagDeleted(String name) =>
      context.read<TagFilterProvider>().removeTag(name);

  void _onSelectAllTags() {
    final clipProvider = context.read<ClipProvider>();
    if (clipProvider.distinctTags.isEmpty) return;

    context.read<TagFilterProvider>().setTags(
          clipProvider.distinctTags.map((t) => t.name),
        );
  }

  void _onClearResult() => context.read<TagFilterProvider>().clearTags();

  /// 현재 저장위치 탭에 맞는 pull sync를 실행합니다. 로컬 탭은 당길 게
  /// 없으므로 build()에서 애초에 RefreshIndicator를 안 붙입니다.
  Future<void> _onRefreshRemoteClips() async {
    final clipProvider = context.read<ClipProvider>();
    if (_storageMode == ClipStorageConstants.storageModeServer) {
      await clipProvider.pullRemoteServerClips();
    } else if (_storageMode == ClipStorageConstants.storageModeGoogleDrive) {
      await clipProvider.pullRemoteCloudClips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clipProvider = context.watch<ClipProvider>();
    final tagProv = context.watch<TagFilterProvider>();

    final isClipTab = _tabController.index == 0;
    // 바깥 탭(클립/문장/단어)과 전체선택 액션을 가리는 조건 — 기존 AppBar의
    // bottom: isSelectionMode ? null : TabBar 조건과 동일.
    final isShellSelectionMode = clipProvider.isCollectionMenuOpen && isClipTab;
    // 저장위치·폴더/태그 탭(zone2)을 가리는 조건 — 기존 LibraryScreen의
    // isSelectionMode 조건과 동일 (콜렉션 내부에서 클립을 다중 선택 중일 때).
    final isCollectionSelectionMode = clipProvider.isCollectionMenuOpen &&
        clipProvider.selectedCollectionId != null;

    final visibleClipIds =
        clipProvider.clipItems.map((item) => item.clip.id).toSet();
    final selectedClipIds = clipProvider.selectedClipIds;
    final isAllSelected = visibleClipIds.isNotEmpty &&
        visibleClipIds.length == selectedClipIds.length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: NestedScrollView(
          controller: _outerScrollController,
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverPersistentHeader(
                floating: true,
                delegate: CollectionHeaderDelegate(
                  titleWidget: _buildTitleBar(
                    context,
                    clipProvider,
                    isShellSelectionMode,
                    visibleClipIds: visibleClipIds,
                    isAllSelected: isAllSelected,
                  ),
                  zone1Widget: _buildTabBar(context),
                  zone2Widget: _buildStorageAndBookmarkTabs(context),
                  zone1Height: isShellSelectionMode ? 0 : 48,
                  // 8(gap) + 59.6(StorageScopeTabs) + 8(gap) + 59.6(BookmarkTabs) + 10(gap) = 145.2.
                  // 59.6 = 42(내부 콘텐츠) + 8*2(AppSpacing.sm 패딩) + 0.8*2(Border.all
                  // 두께 — Container가 decoration의 border를 padding에 합산해서 추가함).
                  zone2Height:
                      (isClipTab && !isCollectionSelectionMode) ? 146 : 0,
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            physics: _headerVisible
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            children: [
              _buildClipTabContent(context, clipProvider, tagProv),
              Center(
                child: Text(
                  '문장 노트 준비 중',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              Center(
                child: Text(
                  '나만의 단어장 준비 중',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(
    BuildContext context,
    ClipProvider clipProvider,
    bool isSelectionMode, {
    required Set<int> visibleClipIds,
    required bool isAllSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '콜렉션',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (isSelectionMode)
            TextButton(
              onPressed: visibleClipIds.isEmpty
                  ? null
                  : () {
                      if (isAllSelected) {
                        clipProvider.clearClipSelection();
                      } else {
                        clipProvider.selectAllVisibleClips();
                      }
                    },
              child: Text(isAllSelected ? '전체 해제' : '전체 선택'),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: colorScheme.onSurface,
      labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      unselectedLabelStyle:
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      indicatorColor: colorScheme.onSurface,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      tabs: const [
        Tab(text: '클립'),
        Tab(text: '문장'),
        Tab(text: '단어'),
      ],
    );
  }

  Widget _buildStorageAndBookmarkTabs(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        StorageScopeTabs(
          value: _storageMode,
          onChanged: _onStorageModeChanged,
        ),
        const SizedBox(height: 8),
        BookmarkTabs(
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildClipTabContent(
    BuildContext context,
    ClipProvider clipProvider,
    TagFilterProvider tagProv,
  ) {
    if (_tab == LibraryTab.tag) {
      return LibraryTagSection(
        allTags: clipProvider.distinctTags,
        selectedTags: tagProv.activeTagNames.toSet(),
        onTagSelected: _onTagSelected,
        onTagDeleted: _onTagDeleted,
        onSelectAll: _onSelectAllTags,
        onClearResult: _onClearResult,
      );
    }

    if (_storageMode == ClipStorageConstants.storageModeLocal) {
      return const LibraryFolderSection();
    }

    return RefreshIndicator(
      onRefresh: _onRefreshRemoteClips,
      child: const LibraryFolderSection(),
    );
  }
}
