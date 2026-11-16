import 'package:parrokit/core/app/router/tab_reselect.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/board/presentation/board_screen.dart';
import 'package:parrokit/features/community/question/presentation/question_screen.dart';
import 'package:parrokit/features/community/vote/presentation/vote_screen.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/share_my_sentence_sheet.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';
import 'package:parrokit/features/community/shell/presentation/sections/community_shell_filters_section.dart';
import 'package:parrokit/features/community/shell/presentation/sections/community_shell_write_sheet.dart';
import 'package:parrokit/core/shared/widgets/tiered_header.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/widgets/expandable_action_fab.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class CommunityShellScreen extends StatefulWidget {
  const CommunityShellScreen({super.key});

  /// 커뮤니티 탭 차례. 0 게시판, 1 문장, 2 질문, 3 투표.
  static const int boardTab = 0;
  static const int sentenceTab = 1;
  static const int questionTab = 2;
  static const int voteTab = 3;

  /// 다른 화면에서 커뮤니티의 특정 탭을 열어 달라고 할 때 쓴다(5차 340).
  /// 보관함·홈의 '전체 보기'가 문장 탭으로 바로 온다.
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static void openTab(int tab) {
    requestedTab.value = null;
    requestedTab.value = tab;
  }

  @override
  State<CommunityShellScreen> createState() => _CommunityShellScreenState();
}

class _CommunityShellScreenState extends State<CommunityShellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _outerScrollController = ScrollController();

  String _selectedBoardFilter = CommunityFilters.defaultBoard;
  String _selectedQuestionStatus = CommunityFilters.defaultQuestionStatus;
  String _selectedQuestionSort = CommunityFilters.defaultQuestionSort;
  String _selectedVoteFilter = CommunityFilters.defaultVote;

  int _currentIndex = 0;
  bool _isFabExtended = true;
  bool _headerVisible = true;

  String _normalizedVoteFilter(String value) {
    if (value == '랜덤 보기') return CommunityFilters.vote[0];
    return CommunityFilters.vote.contains(value)
        ? value
        : CommunityFilters.defaultVote;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onTabChanged);
    CommunityShellScreen.requestedTab.addListener(_handleTabRequest);
    final requested = CommunityShellScreen.requestedTab.value;
    if (requested != null) _tabController.index = requested;
    _outerScrollController.addListener(_checkHeaderVisibility);
    TabReselect.instance.addListener(_onTabReselected);
  }

  /// 커뮤니티에서 커뮤니티 탭을 다시 누르면 위 머리 부분이 다시 보이게 올린다.
  void _onTabReselected() {
    if (TabReselect.instance.lastIndex != 1) return;
    if (!_outerScrollController.hasClients) return;
    _outerScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleTabRequest() {
    final tab = CommunityShellScreen.requestedTab.value;
    if (tab == null || !mounted || tab == _tabController.index) return;
    _tabController.animateTo(tab);
  }

  void _onTabChanged() {
    if (_currentIndex == _tabController.index) return;
    setState(() => _currentIndex = _tabController.index);
  }

  void _checkHeaderVisibility() {
    final fullyVisible = _outerScrollController.offset <= 1.0;
    if (_headerVisible == fullyVisible) return;
    setState(() {
      _headerVisible = fullyVisible;
      _isFabExtended = fullyVisible;
    });
  }

  @override
  void dispose() {
    CommunityShellScreen.requestedTab.removeListener(_handleTabRequest);
    TabReselect.instance.removeListener(_onTabReselected);
    _tabController.removeListener(_onTabChanged);
    _outerScrollController.removeListener(_checkHeaderVisibility);
    _outerScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // Scaffold.floatingActionButton은 body와 별개 레이어라서 스크롤뷰의
      // 오버스크롤 효과와 겹치는 문제 자체가 생기지 않습니다. 대시보드와
      // 동일하게 세이프에어리어(bottomInset)만큼만 띄웁니다.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        // 질문·투표 탭에서는 고르는 시트 없이 그 글쓰기로 바로 간다. 질문
        // 탭에 와서 '글쓰기'를 누르면 게시판·질문·투표를 다시 골라야 했다.
        // 게시판 탭은 지금처럼 시트를 연다(5차 결정).
        child: ExpandableActionFab(
          isExtended: _isFabExtended,
          icon: Icons.add,
          label: switch (_currentIndex) {
            CommunityShellScreen.sentenceTab => '문장 공유하기',
            CommunityShellScreen.questionTab => '질문하기',
            CommunityShellScreen.voteTab => '투표 만들기',
            _ => '글쓰기',
          },
          onTap: () => switch (_currentIndex) {
            // 문장 탭에서는 내 문장을 골라 둘러보기에 올린다(5차 340).
            CommunityShellScreen.sentenceTab =>
              showShareMySentenceSheet(context),
            CommunityShellScreen.questionTab =>
              context.push(AppRoutes.communityQuestionWritePath),
            CommunityShellScreen.voteTab =>
              context.push(AppRoutes.communityVoteWritePath),
            _ => showCommunityWriteBottomSheet(context),
          },
          backgroundColor: AppColors.communityBoardAccent,
          foregroundColor: colorScheme.onPrimary,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.22),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          iconSize: 24,
        ),
      ),
      body: SafeArea(
        child: NestedScrollView(
          controller: _outerScrollController,
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverPersistentHeader(
                floating: true,
                // 보관함과 같은 n단 머리줄 모듈을 쓴다(5차 335).
                delegate: TieredHeaderDelegate(
                  tiers: [
                    HeaderTier(height: 56, child: _buildTitleBar(context)),
                    // 탭 줄은 맨 위에 붙어 버틴다. 어느 탭인지 계속 보여야 한다.
                    HeaderTier(
                      height: 48,
                      sticky: true,
                      child: _buildTabBar(context),
                    ),
                    // 게시판은 가로 스크롤 칩 줄, 질문·투표는 세그먼트 컨트롤이라
                    // 필요한 높이가 다르다. 게시판은 위 여백 12 + 칩 44 +
                    // 아래 여백 11 + 구분선 1 = 68이다.
                    HeaderTier(
                      height: switch (_tabController.index) {
                        CommunityShellScreen.boardTab => 68,
                        // 문장 탭은 제 화면 안에 언어·주제 줄이 있어서
                        // 머리줄에는 구분선만 둔다(5차 340).
                        CommunityShellScreen.sentenceTab => 13,
                        _ => 72,
                      },
                      child: _buildFilterSection(),
                    ),
                  ],
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
              BoardScreen(selectedFilter: _selectedBoardFilter),
              // 공유된 문장 둘러보기(5차 340, 사용자 요청). 언어·주제 줄은
              // 이 화면이 제 안에 들고 있어서 머리줄 필터 자리는 비워 둔다.
              const SentenceCollectionPreview(exploreOnly: true),
              QuestionScreen(
                selectedStatus: _selectedQuestionStatus,
                selectedSort: _selectedQuestionSort,
              ),
              VoteScreen(
                selectedFilter: _normalizedVoteFilter(_selectedVoteFilter),
                swipeEnabled: !_headerVisible,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 4.0, 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '커뮤니티',
            style: context.texts.headlineMedium
                .copyWith(color: colorScheme.onSurface),
          ),
          Row(
            children: [
              // 검색 버튼은 뺐다(5차). 검색 화면이 아직 없어 흐린 아이콘만 있었고,
              // 눌러도 아무 일이 없어 고장 난 것처럼 보였다(원칙 5 "안 되는 건
              // 보이지 않게"). 검색을 만들면 여기에 다시 둔다.
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  final unreadCount = userProvider.unreadNotificationCount;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: '알림',
                        icon: Icon(Icons.notifications_none,
                            color: colorScheme.onSurface),
                        onPressed: () =>
                            context.push(AppRoutes.communityNotificationPath),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            constraints: const BoxConstraints(
                                minWidth: 20, minHeight: 20),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: colorScheme.surface, width: 2),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              textAlign: TextAlign.center,
                              style: context.texts.labelSmall
                                  .copyWith(color: Colors.white, height: 1),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                tooltip: '커뮤니티 메뉴',
                icon: Icon(Icons.menu, color: colorScheme.onSurface),
                onPressed: () => context.push(AppRoutes.communityMenuPath),
              ),
            ],
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
      labelStyle: context.texts.titleLarge,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      unselectedLabelStyle: context.texts.titleLarge,
      indicatorColor: colorScheme.onSurface,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      tabs: const [
        Tab(text: '게시판'),
        // 공유된 문장 둘러보기가 여기로 들어왔다(5차 340, 사용자 요청).
        Tab(text: '문장'),
        Tab(text: '질문'),
        Tab(text: '투표'),
      ],
    );
  }

  Widget _buildFilterSection() {
    // 문장 탭은 거르는 줄이 그 화면 안에 있다(언어·주제).
    if (_tabController.index == CommunityShellScreen.sentenceTab) {
      return Column(children: [
        const SizedBox(height: 12),
        Divider(color: context.tokens.disabled, height: 1),
      ]);
    }
    return Column(
      children: [
        const SizedBox(height: 12),
        CommunityShellFiltersSection(
          // 거르는 줄은 게시판·질문·투표 셋만 안다. 문장 탭이 가운데
          // 끼어들었으니 차례를 맞춰 넘긴다(5차 340).
          tabIndex: _tabController.index == CommunityShellScreen.boardTab
              ? 0
              : _tabController.index - 1,
          selectedBoardFilter: _selectedBoardFilter,
          selectedQuestionStatus: _selectedQuestionStatus,
          selectedQuestionSort: _selectedQuestionSort,
          selectedVoteFilter: _selectedVoteFilter,
          onBoardFilterSelected: (value) =>
              setState(() => _selectedBoardFilter = value),
          onQuestionStatusSelected: (value) =>
              setState(() => _selectedQuestionStatus = value),
          onQuestionSortSelected: (value) =>
              setState(() => _selectedQuestionSort = value),
          onVoteFilterSelected: (value) => setState(
              () => _selectedVoteFilter = _normalizedVoteFilter(value)),
        ),
        const SizedBox(height: 11),
        Divider(color: context.tokens.disabled, height: 1),
      ],
    );
  }
}
