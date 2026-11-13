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
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';
import 'package:parrokit/features/community/shell/presentation/sections/community_shell_filters_section.dart';
import 'package:parrokit/features/community/shell/presentation/sections/community_shell_write_sheet.dart';
import 'package:parrokit/features/community/shell/presentation/widgets/community_header_delegate.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/widgets/expandable_action_fab.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class CommunityShellScreen extends StatefulWidget {
  const CommunityShellScreen({super.key});

  @override
  State<CommunityShellScreen> createState() => _CommunityShellScreenState();
}

class _CommunityShellScreenState extends State<CommunityShellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _outerScrollController = ScrollController();

  String _selectedBoardFilter = CommunityFilters.defaultBoard;
  String _selectedQuestionFilter = CommunityFilters.defaultQuestion;
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
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
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
            1 => '질문하기',
            2 => '투표 만들기',
            _ => '글쓰기',
          },
          onTap: () => switch (_currentIndex) {
            1 => context.push(AppRoutes.communityQuestionWritePath),
            2 => context.push(AppRoutes.communityVoteWritePath),
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
                delegate: CommunityHeaderDelegate(
                  titleWidget: _buildTitleBar(context),
                  zone1Widget: _buildTabBar(context),
                  zone2Widget: _buildFilterSection(),
                  // 게시판은 가로 스크롤 칩 줄, 질문·투표는 세그먼트 컨트롤이라
                  // 필요한 높이가 다르다. 게시판은 위 여백 12 + 칩 44 +
                  // 아래 여백 11 + 구분선 1 = 68이다.
                  zone2Height: _tabController.index == 0 ? 68 : 72,
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
              QuestionScreen(selectedFilter: _selectedQuestionFilter),
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
        Tab(text: '질문'),
        Tab(text: '투표'),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Column(
      children: [
        const SizedBox(height: 12),
        CommunityShellFiltersSection(
          tabIndex: _tabController.index,
          selectedBoardFilter: _selectedBoardFilter,
          selectedQuestionFilter: _selectedQuestionFilter,
          selectedVoteFilter: _selectedVoteFilter,
          onBoardFilterSelected: (value) =>
              setState(() => _selectedBoardFilter = value),
          onQuestionFilterSelected: (value) =>
              setState(() => _selectedQuestionFilter = value),
          onVoteFilterSelected: (value) => setState(
              () => _selectedVoteFilter = _normalizedVoteFilter(value)),
        ),
        const SizedBox(height: 11),
        Divider(color: context.tokens.disabled, height: 1),
      ],
    );
  }
}
