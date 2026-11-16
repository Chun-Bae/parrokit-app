import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/collection/library/presentation/clip_library_home.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/home/dashboard/presentation/add_sentence_screen.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/library/domain/library_mode.dart';
import 'package:parrokit/features/collection/library/presentation/providers/tag_filter_provider.dart';
import 'package:parrokit/features/collection/library/presentation/sections/library_folder_section.dart';
import 'package:parrokit/features/collection/library/presentation/sections/library_tag_section.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/bookmark_tabs.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/storage_scope_tabs.dart';

import 'library_search.dart';
import 'widgets/sentence_collection_preview.dart';
import 'widgets/word_collection_preview.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/shared/widgets/tiered_header.dart';
import 'widgets/collection_header_slot.dart';

class CollectionShellScreen extends StatefulWidget {
  const CollectionShellScreen({super.key});

  /// 다른 화면에서 보관함의 특정 탭(0 문장, 1 클립, 2 단어)을 열어 달라고 할 때 쓴다.
  /// 예전엔 마지막에 본 탭이 그대로 열려, 학습하기의 '영상 고르기'가 단어 탭으로
  /// 가곤 했다(5차). 보관함이 이미 떠 있어도 이 값을 보고 탭을 바꾼다.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  /// [tab]을 열도록 요청한다. 다음에 보관함이 만들어질 때도 이 탭으로 시작한다.
  static void openTab(int tab) {
    AppConfig.libraryTab = tab;
    requestedTab.value = null;
    requestedTab.value = tab;
  }

  @override
  State<CollectionShellScreen> createState() => _CollectionShellScreenState();
}

class _CollectionShellScreenState extends State<CollectionShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  LibraryTab _clipView = LibraryTab.folder;

  /// 탭 안쪽 화면이 올려 두는 머리줄 단(문장 탭, 단어 탭). 클립 탭은 아직 없다.
  /// 이 단들이 앱바·탭 아래에 붙어, 커뮤니티처럼 덜 중요한 줄부터 접힌다(5차 336).
  late final Map<int, CollectionHeaderSlot> _headerSlots;
  String _storageMode = ClipStorageConstants.storageModeLocal;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: AppConfig.libraryTab,
    );
    _tabController.addListener(_handleTabChanged);
    _headerSlots = {
      for (final tab in [0, 2])
        tab: CollectionHeaderSlot(onHeightsChanged: () {
          if (mounted) setState(() {});
        }),
    };
    CollectionShellScreen.requestedTab.addListener(_handleTabRequest);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final clipProvider = context.read<ClipProvider>();
      final tagProvider = context.read<TagFilterProvider>();

      await tagProvider.startWatching();
      if (!mounted) return;
      clipProvider.startWatchingDistinctTags();
      await clipProvider.setActiveStorageMode(_storageMode);
    });
  }

  void _handleTabRequest() {
    final tab = CollectionShellScreen.requestedTab.value;
    if (tab == null || !mounted || tab == _tabController.index) return;
    _tabController.animateTo(tab);
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging || !mounted) return;
    setState(() {});
    if (AppConfig.libraryTab != _tabController.index) {
      AppConfig.libraryTab = _tabController.index;
      AppConfig.saveToPrefs();
    }
    if (_tabController.index != 1) {
      context.read<ClipProvider>().closeCollectionMenu();
    }
  }

  @override
  void dispose() {
    CollectionShellScreen.requestedTab.removeListener(_handleTabRequest);
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    for (final slot in _headerSlots.values) {
      slot.dispose();
    }
    super.dispose();
  }

  void _onStorageModeChanged(String mode) {
    if (_storageMode == mode) return;
    setState(() => _storageMode = mode);
    context.read<ClipProvider>().setActiveStorageMode(mode);
  }

  void _onTagSelected(Tag tag) =>
      context.read<TagFilterProvider>().addTag(tag.name);

  void _onTagDeleted(String name) =>
      context.read<TagFilterProvider>().removeTag(name);

  void _onSelectAllTags() {
    final clipProvider = context.read<ClipProvider>();
    if (clipProvider.distinctTags.isEmpty) return;
    context.read<TagFilterProvider>().setTags(
          clipProvider.distinctTags.map((tag) => tag.name),
        );
  }

  void _onClearResult() => context.read<TagFilterProvider>().clearTags();

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
    final colors = Theme.of(context).colorScheme;
    final clipProvider = context.watch<ClipProvider>();
    final tagProvider = context.watch<TagFilterProvider>();
    final isClipTab = _tabController.index == 1;
    final isClipSelectionMode = isClipTab && clipProvider.isCollectionMenuOpen;
    final isCollectionSelectionMode =
        isClipSelectionMode && clipProvider.selectedCollectionId != null;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        // 머리줄은 커뮤니티와 같은 방식으로 접힌다(5차 332, 사용자 요청).
        // 단을 목록으로 넘기므로 나중에 언어·태그 줄을 한 단 더 얹을 수 있다.
        child: TieredHeaderScroll(
          tiers: [
            HeaderTier(
              height: 56,
              child: _buildTopBar(
                context,
                clipProvider,
                isSelectionMode: isClipSelectionMode,
              ),
            ),
            if (!isClipSelectionMode) ...[
              HeaderTier(
                // 세그먼트 48 + 위 4 + 아래 8 + 테두리 여유.
                height: 82,
                // 문장·클립·단어 탭 줄은 맨 위에 붙어 마지막까지 버틴다.
                // 어느 탭에 있는지가 가장 중요해서다(커뮤니티와 같다, 5차 336).
                sticky: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: _buildCollectionTabs(context),
                ),
              ),
              // 탭 안쪽 화면이 올려 둔 줄(언어·주제, 둘러보기). 탭 줄 아래에
              // 있어서 탭 줄보다 먼저 접힌다.
              ...?_headerSlots[_tabController.index]?.tiers(),
            ],
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _KeepAlive(
                child: SentenceCollectionPreview(
                  headerSlot: _headerSlots[0],
                ),
              ),
              // 새 클립 화면(폴더 + 모든 클립). 더보기 > 앱에서 끄면 예전 화면.
              ValueListenableBuilder<bool>(
                valueListenable: AppConfig.newClipLibraryListenable,
                builder: (context, useNew, _) => useNew
                    ? const ClipLibraryHome()
                    : _buildClipPage(
                        context,
                        clipProvider,
                        tagProvider,
                        hideControls: isCollectionSelectionMode,
                      ),
              ),
              _KeepAlive(
                child: WordCollectionPreview(headerSlot: _headerSlots[2]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ClipProvider clipProvider, {
    required bool isSelectionMode,
  }) {
    final selectedCount = clipProvider.selectedClipIds.length;
    final visibleClipIds =
        clipProvider.clipItems.map((item) => item.clip.id).toSet();
    final isAllSelected =
        visibleClipIds.isNotEmpty && visibleClipIds.length == selectedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
      child: Row(
        children: [
          if (isSelectionMode)
            IconButton(
              tooltip: '선택 닫기',
              onPressed: clipProvider.closeCollectionMenu,
              icon: const Icon(Icons.close_rounded),
            ),
          Expanded(
            child: Text(
              isSelectionMode ? '$selectedCount개 선택' : '보관함',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
            ),
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
            )
          else ...[
            IconButton.filledTonal(
              tooltip: '보관함 검색',
              onPressed: () => _showSearchSheet(context),
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: '새 항목 추가',
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AnimatedBuilder(
        // TabBarView를 쓸어 넘길 때도 선택 표시가 같이 움직이도록
        // 컨트롤러의 애니메이션 값을 따라간다.
        animation: _tabController.animation ?? _tabController,
        builder: (context, _) => AppSegmentedTabs(
          stacked: true,
          selectedIndex: (_tabController.animation?.value ??
                  _tabController.index.toDouble())
              .round(),
          position: _tabController.animation?.value,
          onChanged: _tabController.animateTo,
          segments: const [
            AppSegment(icon: Icons.format_quote_rounded, label: '문장'),
            AppSegment(icon: Icons.smart_display_rounded, label: '클립'),
            AppSegment(icon: Icons.spellcheck_rounded, label: '단어'),
          ],
        ),
      ),
    );
  }

  Widget _buildClipPage(
    BuildContext context,
    ClipProvider clipProvider,
    TagFilterProvider tagProvider, {
    required bool hideControls,
  }) {
    return Column(
      children: [
        if (!hideControls) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => context.pushNamed(AppRoutes.clipDiscover),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: const Text('이어보기·추천'),
              ),
            ),
          ),
          StorageScopeTabs(
            value: _storageMode,
            onChanged: _onStorageModeChanged,
          ),
          const SizedBox(height: 8),
          BookmarkTabs(
            value: _clipView,
            onChanged: (value) => setState(() => _clipView = value),
          ),
          const SizedBox(height: 4),
        ],
        Expanded(
          child: _buildClipContent(context, clipProvider, tagProvider),
        ),
      ],
    );
  }

  Widget _buildClipContent(
    BuildContext context,
    ClipProvider clipProvider,
    TagFilterProvider tagProvider,
  ) {
    if (_clipView == LibraryTab.tag) {
      return LibraryTagSection(
        allTags: clipProvider.distinctTags,
        selectedTags: tagProvider.activeTagNames.toSet(),
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

  Future<void> _showSearchSheet(BuildContext context) async {
    final accountId = context.read<UserProvider?>()?.currentUser?.id ?? 'guest';
    // 예전엔 입력칸만 있고 아무것도 찾지 않았다. 이제 내 문장·단어와 클립
    // 제목·자막에서 찾는다(5차).
    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 손잡이는 앱 테마(showDragHandle)가 그린다. 예전엔 직접 하나 더 그려 둘이었다.
              Text(
                '보관함 검색',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LibrarySearchSheet(
                  accountId: accountId,
                  onOpenClip: (clipId) => context.push(
                    '${AppRoutes.clipsPath}/${AppRoutes.clipsPlayPath}?clipId=$clipId',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 문장 탭의 + 버튼과 같은 문장 추가 화면을 연다.
  Future<void> _addSentence(BuildContext context) async {
    final accountId = context.read<UserProvider?>()?.currentUser?.id ?? 'guest';
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await addSentenceFlow(
        context,
        accountId: accountId,
        language: '영어',
      );
      if (result == null) return;
      messenger.showSnackBar(SnackBar(
          content:
              Text(result.added ? '추가했어요. 홈 앵무새가 말해줘요.' : '이미 있는 문장이에요.')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('문장을 저장하지 못했어요. 다시 시도해 주세요.')));
    }
  }

  /// 단어 탭의 + 버튼과 같은 단어 추가 창을 연다. 언어는 위 문장 추가와 같이
  /// 영어로 넣는다(다른 언어는 단어 탭에서 언어를 고른 뒤 + 로 넣는다).
  Future<void> _addWord(BuildContext context) async {
    final accountId = context.read<UserProvider?>()?.currentUser?.id ?? 'guest';
    final result = await showAppSheet<WordAddResult>(
      context: context,
      builder: (_) => AddWordSheet(accountId: accountId, language: '영어'),
    );
    if (!context.mounted || result == null) return;
    showWordAddResult(context, result);
  }

  Future<void> _showAddSheet(BuildContext context) async {
    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Text(
                  // '재료'는 앱의 다른 곳에서 쓰지 않는 말이었다(5차).
                  // 아래 줄들이 모두 '…추가'이니 묻는 말로 둔다.
                  '무엇을 추가할까요?',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _AddMaterialTile(
                icon: Icons.format_quote_rounded,
                title: '문장 추가',
                subtitle: '원문과 뜻을 직접 적어요',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _tabController.animateTo(0);
                  _addSentence(context);
                },
              ),
              _AddMaterialTile(
                icon: Icons.smart_display_rounded,
                title: '클립 추가',
                subtitle: '영상과 자막을 함께 보관해요',
                // 예전엔 탭만 바꿔서 '추가'를 눌러도 아무것도 열리지 않았다(5차).
                // 문장 추가처럼 바로 클립 만들기 화면을 연다.
                onTap: () {
                  Navigator.pop(sheetContext);
                  _tabController.animateTo(1);
                  context.push(
                      '${AppRoutes.clipsPath}/${AppRoutes.clipsCreatePath}');
                },
              ),
              _AddMaterialTile(
                icon: Icons.spellcheck_rounded,
                title: '단어 추가',
                // 예전 '문장 속 표현을 따로 표시해요'는 단어 탭이 예시 화면이던 때 말(5차).
                subtitle: '단어와 뜻을 저장하고 복습해요',
                // 클립과 같은 이유로 단어 추가 창을 바로 연다.
                onTap: () {
                  Navigator.pop(sheetContext);
                  _tabController.animateTo(2);
                  _addWord(context);
                },
              ),
              // TTS·영상 만들기는 예전엔 '콘텐츠 제작' 한 줄 안에 숨어 있어 없어진
              // 줄 알았다(5차, 사용자 의견). 바로 보이게 따로 둔다. 자막 만들기는
              // 위 '클립 추가'와 같은 화면이다. 허브 안에서 세 탭을 오갈 수 있고,
              // push로 열어 나가면 보관함으로 돌아온다.
              _AddMaterialTile(
                icon: Icons.graphic_eq_rounded,
                title: '음성 만들기',
                subtitle: '문장을 읽어 주는 음성을 만들어요',
                usesParrots: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('${AppRoutes.contentStudioHubPath}?tab=1');
                },
              ),
              if (kVideoStudioEnabled)
                _AddMaterialTile(
                  icon: Icons.movie_creation_outlined,
                  title: '영상 만들기',
                  subtitle: '대본으로 짧은 영상을 만들어요',
                  usesParrots: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('${AppRoutes.contentStudioHubPath}?tab=2');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 패롯이 드는 줄에 붙이는 말. 그냥 저장하는 줄과 섞여 있어서, 누르기 전에
/// 알 수 있어야 한다(5차).
const String addSheetUsesParrotsLabel = '패롯 써요';

/// 테스트에서 줄 하나만 그려 보려고 열어 둔다.
@visibleForTesting
Widget addMaterialTileForTest({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  bool usesParrots = false,
}) =>
    _AddMaterialTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      usesParrots: usesParrots,
    );

class _AddMaterialTile extends StatelessWidget {
  const _AddMaterialTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.usesParrots = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// 누르면 패롯이 드는지. 만들기(음성·영상)만 든다.
  final bool usesParrots;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (usesParrots)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              addSheetUsesParrotsLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
        const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }
}

/// TabBarView는 화면 밖으로 넘긴 탭을 버리고 돌아올 때 새로 만든다. 그때마다
/// 목록을 다시 읽으며 깜빡여서, 보관함 탭들은 살려 둔다.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
