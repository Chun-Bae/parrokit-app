import 'package:parrokit/core/app/router/tab_reselect.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/features/collection/shell/presentation/collection_shell_screen.dart';
import 'package:parrokit/features/collection/shell/presentation/open_shared_sentences.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/content/practice_calendar.dart';

import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'package:parrokit/core/shared/widgets/tip_dialog.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'widgets/study_garden_preview.dart';
import 'widgets/sentence_history_dashboard.dart';
import 'widgets/today_practice_summary.dart';
import 'widgets/today_start_bar.dart';
import 'widgets/trending_sentences_preview.dart';
import 'stage_preview_screen.dart';

/// 앱 홈 화면. 앵무새 무대([StagePreviewScreen])를 맨 위에 품고,
/// 연습 기록과 추천 문장, 학습 잔디를 함께 보여준다.
/// 연습 횟수와 하루 목표는 기기에 저장한다.
class CharacterDashboardScreen extends StatefulWidget {
  const CharacterDashboardScreen({super.key});

  @override
  State<CharacterDashboardScreen> createState() =>
      _CharacterDashboardScreenState();
}

class _CharacterDashboardScreenState extends State<CharacterDashboardScreen> {
  late final ScrollController scrollController;
  String language = '영어';
  bool showScrollToTop = false;
  String? loadedAccountId;
  int dailyGoal = 5;
  int totalPracticed = 0;
  Map<String, int> practiceCounts = {};
  Map<String, int> practiceGoals = {};

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController()..addListener(handleScroll);
    TabReselect.instance.addListener(_onTabReselected);
    // 보관함 문장 창에서 따라 말해도 캘린더가 바로 따라오게 한다(5차 351).
    PracticeCalendar.revision.addListener(_reloadPracticeStats);
    // 홈 첫 진입에서 한 번 팁을 보여준다 (예전에는 클래식 대시보드가 띄웠다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showTipDialog(context);
    });
  }

  void _reloadPracticeStats() {
    final accountId = loadedAccountId;
    if (accountId == null || !mounted) return;
    unawaited(loadPracticeStats(accountId));
  }

  void handleScroll() {
    final next = scrollController.hasClients && scrollController.offset > 360;
    if (next != showScrollToTop) setState(() => showScrollToTop = next);
  }

  /// 홈에서 홈 탭을 다시 누르면 맨 위로.
  void _onTabReselected() {
    if (TabReselect.instance.lastIndex == 2) scrollToTop();
  }

  Future<void> scrollToTop() async {
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  String dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void ensureStatsLoaded(String accountId) {
    if (loadedAccountId == accountId) return;
    loadedAccountId = accountId;
    unawaited(loadPracticeStats(accountId));
  }

  Future<void> loadPracticeStats(String accountId) async {
    try {
      // 읽는 곳도 적는 곳과 같은 PracticeCalendar를 쓴다(5차 351). 전에는
      // 홈이 따로 해독해서, 목표 키가 어긋나도 모르고 지냈다.
      final data = await PracticeCalendar.load(accountId);
      if (!mounted || loadedAccountId != accountId) return;
      setState(() {
        dailyGoal = data.dailyGoal;
        practiceCounts = data.counts;
        practiceGoals = data.goals;
        totalPracticed = data.total;
      });
    } catch (_) {
      // 기록을 읽지 못해도 현재 화면에서는 기본 목표로 계속 연습할 수 있다.
    }
  }

  Future<void> recordCompletedSentence() async {
    final accountId = loadedAccountId ?? 'guest';
    // 적는 곳은 공용이다. 보관함 문장 창에서 따라 말해도 같은 자리에
    // 쌓인다(5차).
    final data = await PracticeCalendar.recordOne(accountId);
    if (!mounted) return;
    setState(() {
      practiceCounts = data.counts;
      practiceGoals = data.goals;
      totalPracticed = data.total;
    });
  }

  Future<void> editDailyGoal() async {
    final next = await showDialog<int>(
      context: context,
      builder: (context) => DailyGoalDialog(initialGoal: dailyGoal),
    );
    if (!mounted || next == null || next == dailyGoal) return;
    final accountId = loadedAccountId ?? 'guest';
    // 적는 자리는 PracticeCalendar 한 곳이다(5차 352).
    final data = await PracticeCalendar.setDailyGoal(accountId, next);
    if (!mounted) return;
    setState(() {
      dailyGoal = data.dailyGoal;
      practiceGoals = data.goals;
    });
  }

  @override
  void dispose() {
    PracticeCalendar.revision.removeListener(_reloadPracticeStats);
    TabReselect.instance.removeListener(_onTabReselected);
    scrollController
      ..removeListener(handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider?>()?.currentUser;
    final accountId = user?.id ?? 'guest';
    ensureStatsLoaded(accountId);
    final isDark = HomeTokens.isDark(context);
    final palette = HomeTokens.of(context);
    final background = palette.background;
    // 앱 테마를 통째로 갈아끼우지 않고 파생시킨다. 테마를 새로 만들면
    // AppTheme이 정의한 컴포넌트 테마(버튼·다이얼로그·입력 등)와 색 토큰이
    // 이 화면 안에서 전부 사라진다.
    final appTheme = Theme.of(context);
    final localTheme = appTheme.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: appTheme.colorScheme.copyWith(
        surface: palette.surface,
        primary: palette.primary,
        onSurface: palette.ink,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Theme(
        data: localTheme,
        child: Scaffold(
          backgroundColor: background,
          body: Stack(children: [
            SafeArea(
              top: false,
              bottom: false,
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  0,
                  0,
                  0,
                  MediaQuery.paddingOf(context).bottom + 120,
                ),
                children: [
                  StagePreviewScreen(
                      key: ValueKey(accountId),
                      embedded: true,
                      language: language,
                      nickname: user?.displayName ?? '나',
                      accountId: accountId,
                      onPracticeCompleted: recordCompletedSentence),
                  // 오늘 목표와 학습 시작을 무대 바로 아래에(4차).
                  TodayStartBar(
                    completed: practiceCounts[dateKey(DateTime.now())] ?? 0,
                    goal: dailyGoal,
                    onStart: () => context.push(AppRoutes.learningHubPath),
                    onEditGoal: editDailyGoal,
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    LearningLanguagePicker(
                      value: language,
                      compact: true,
                      onChanged: (value) => setState(() => language = value),
                    ),
                    // 예전엔 오른쪽에 '누적 N문장'이 있었다. 모든 언어 합계인데 언어
                    // 고르기 옆이라 고른 언어의 숫자처럼 보였고, 아래 학습 기록에도
                    // 같은 숫자가 있어 뺐다(5차).
                  ]),
                  const SizedBox(height: 16),
                  SentenceHistoryDashboard(
                    accountId: accountId,
                    language: language,
                    refreshToken: totalPracticed,
                    compact: true,
                    // 문장 기록이라 보관함 문장 탭을 연다(마지막에 본 탭이 아니라, 5차).
                    onViewAll: () {
                      CollectionShellScreen.openTab(CollectionShellScreen.sentenceTab);
                      context.go(AppRoutes.collectionPath);
                    },
                  ),
                  const SizedBox(height: 30),
                  TrendingSentencesPreview(
                    language: language,
                    onViewAll: () => openSharedSentences(context),
                    onOpenLibrary: () {
                      CollectionShellScreen.openTab(CollectionShellScreen.sentenceTab);
                      context.go(AppRoutes.collectionPath);
                    },
                  ),
                  const SizedBox(height: 30),
                  StudyGardenPreview(
                    practiceCounts: practiceCounts,
                    practiceGoals: practiceGoals,
                    dailyGoal: dailyGoal,
                    totalPracticed: totalPracticed,
                  ),
                ]
                    .map((child) => child is StagePreviewScreen
                        ? child
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: child))
                    .toList(),
              ),
            ),
            Positioned(
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 92,
                child: IgnorePointer(
                    ignoring: !showScrollToTop,
                    child: AnimatedSlide(
                        offset: showScrollToTop
                            ? Offset.zero
                            : const Offset(0, 1.5),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                            opacity: showScrollToTop ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: FloatingActionButton.small(
                                heroTag: 'dashboard-scroll-to-top',
                                tooltip: '맨 위로',
                                elevation: 3,
                                backgroundColor: palette.surface,
                                foregroundColor: palette.primary,
                                onPressed: scrollToTop,
                                child: const Icon(
                                    Icons.keyboard_arrow_up_rounded)))))),
          ]),
        ),
      ),
    );
  }
}
