import 'package:parrokit/features/content-studio/hub/presentation/studio_tab_names.dart';
import 'package:parrokit/core/content/sentence_share_text.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
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
import 'package:parrokit/features/collection/library/presentation/providers/tag_filter_provider.dart';

import 'library_search.dart';
import 'widgets/sentence_collection_preview.dart';
import 'widgets/word_collection_preview.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/shared/widgets/tiered_header.dart';
import 'widgets/collection_header_slot.dart';
import 'package:parrokit/core/shared/widgets/keep_alive.dart';

class CollectionShellScreen extends StatefulWidget {
  const CollectionShellScreen({super.key});

  /// 탭 자리. 숫자를 직접 적지 말고 이 이름을 쓴다(5차 467).
  /// 순서를 바꿀 때 부르는 쪽이 조용히 어긋나지 않게 한다.
  static const int sentenceTab = 0;
  static const int wordTab = 1;
  static const int clipTab = 2;

  /// 다른 화면에서 보관함의 특정 탭을 열어 달라고 할 때 쓴다.
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

  /// 탭 안쪽 화면이 올려 두는 머리줄 단(문장 탭, 단어 탭). 클립 탭은 아직 없다.
  /// 이 단들이 앱바·탭 아래에 붙어, 커뮤니티처럼 덜 중요한 줄부터 접힌다(5차 336).
  late final Map<int, CollectionHeaderSlot> _headerSlots;
  // 클립 탭은 새 화면만 쓴다. 저장 위치 탭은 없어졌지만, 앱이 켜질 때
  // 어떤 위치를 보고 있는지는 provider에 알려 준다(기본은 이 기기).
  static const String _storageMode = ClipStorageConstants.storageModeLocal;

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
    if (!mounted) return;
    // 머리줄(언어·주제 같은 탭별 줄)은 **누른 즉시** 바꾼다(5차 466).
    //
    // 전에는 indexIsChanging일 때 통째로 건너뛰어서, 넘어가는 동안 앞 탭의
    // 줄이 그대로 남아 있다가 애니메이션이 끝나고서야 바뀌었다. 탭 표시는
    // 손가락을 따라 움직이는데 머리줄만 늦어 어긋나 보였다.
    setState(() {});
    // 아래는 자리가 완전히 바뀐 뒤에만 한다.
    if (_tabController.indexIsChanging) return;
    if (AppConfig.libraryTab != _tabController.index) {
      AppConfig.libraryTab = _tabController.index;
      AppConfig.saveToPrefs();
    }
    if (_tabController.index != CollectionShellScreen.clipTab) {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final clipProvider = context.watch<ClipProvider>();
    final isClipTab = _tabController.index == CollectionShellScreen.clipTab;
    final isClipSelectionMode = isClipTab && clipProvider.isCollectionMenuOpen;

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
              TabKeepAlive(
                child: SentenceCollectionPreview(
                  headerSlot: _headerSlots[CollectionShellScreen.sentenceTab],
                ),
              ),
              TabKeepAlive(
                child: WordCollectionPreview(
                  headerSlot: _headerSlots[CollectionShellScreen.wordTab],
                ),
              ),
              // 클립 탭은 새 화면(폴더 + 모든 클립)만 쓴다. 더보기의 스위치는
              // 없앴다(사용자 결정 2026-11-17).
              // 이 탭만 살려 두지 않아서, 클립으로 옮길 때마다 폴더와 클립을
              // 다시 읽느라 깜빡였다(5차 466).
              const TabKeepAlive(child: ClipLibraryHome()),
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
            // 문장 - 단어 - 클립. 문장과 단어가 붙어 있어야 글끼리 모인다
            // (사용자 결정 2026-11-17).
            AppSegment(icon: Icons.format_quote_rounded, label: '문장'),
            AppSegment(icon: Icons.spellcheck_rounded, label: '단어'),
            AppSegment(icon: Icons.smart_display_rounded, label: '클립'),
          ],
        ),
      ),
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
          content: Text(result.added
              ? sentenceSavedToMineMessage
              : sentenceAlreadySavedMessage)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text(sentenceSaveFailedMessage)));
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
                subtitle: studioClipTabDescription,
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
                subtitle: studioVoiceTabDescription,
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
                  subtitle: studioVideoTabDescription,
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
