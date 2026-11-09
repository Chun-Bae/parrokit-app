import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'package:parrokit/core/shared/widgets/tip_dialog.dart';

import 'home_palette.dart';
import 'widgets/study_garden_preview.dart';
import 'widgets/sentence_history_dashboard.dart';
import 'widgets/today_practice_summary.dart';
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
    // 홈 첫 진입에서 한 번 팁을 보여준다 (예전에는 클래식 대시보드가 띄웠다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showTipDialog(context);
    });
  }

  void handleScroll() {
    final next = scrollController.hasClients && scrollController.offset > 360;
    if (next != showScrollToTop) setState(() => showScrollToTop = next);
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

  String goalKey(String accountId) =>
      'parrokit.practice.daily_goal.v1.$accountId';
  String historyKey(String accountId) =>
      'parrokit.practice.history.v1.$accountId';
  String goalsKey(String accountId) => 'parrokit.practice.goals.v1.$accountId';
  String totalKey(String accountId) => 'parrokit.practice.total.v1.$accountId';

  void ensureStatsLoaded(String accountId) {
    if (loadedAccountId == accountId) return;
    loadedAccountId = accountId;
    unawaited(loadPracticeStats(accountId));
  }

  Future<void> loadPracticeStats(String accountId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawHistory = prefs.getString(historyKey(accountId));
      final rawGoals = prefs.getString(goalsKey(accountId));
      final history = <String, int>{};
      final goals = <String, int>{};
      if (rawHistory != null) {
        final decoded = jsonDecode(rawHistory);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is num && value >= 0) {
              history[entry.key] = value.toInt();
            }
          }
        }
      }
      if (rawGoals != null) {
        final decoded = jsonDecode(rawGoals);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is num && value >= 1 && value <= 100) {
              goals[entry.key] = value.toInt();
            }
          }
        }
      }
      final legacyTotal =
          prefs.getInt('parrokit.speaking.xp.v1.$accountId') ?? 0;
      if (!mounted || loadedAccountId != accountId) return;
      setState(() {
        dailyGoal = (prefs.getInt(goalKey(accountId)) ?? 5).clamp(1, 100);
        practiceCounts = history;
        practiceGoals = goals;
        totalPracticed = prefs.getInt(totalKey(accountId)) ?? legacyTotal;
      });
    } catch (_) {
      // 기록을 읽지 못해도 현재 화면에서는 기본 목표로 계속 연습할 수 있다.
    }
  }

  Future<void> recordCompletedSentence() async {
    final accountId = loadedAccountId ?? 'guest';
    final key = dateKey(DateTime.now());
    final nextHistory = Map<String, int>.from(practiceCounts);
    final nextGoals = Map<String, int>.from(practiceGoals);
    nextHistory[key] = (nextHistory[key] ?? 0) + 1;
    nextGoals.putIfAbsent(key, () => dailyGoal);
    final nextTotal = totalPracticed + 1;

    setState(() {
      practiceCounts = nextHistory;
      practiceGoals = nextGoals;
      totalPracticed = nextTotal;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(historyKey(accountId), jsonEncode(nextHistory)),
        prefs.setString(goalsKey(accountId), jsonEncode(nextGoals)),
        prefs.setInt(totalKey(accountId), nextTotal),
      ]);
    } catch (_) {
      // 현재 실행 중 기록은 유지하고 다음 성공 때 다시 저장을 시도한다.
    }
  }

  Future<void> editDailyGoal() async {
    final next = await showDialog<int>(
      context: context,
      builder: (context) => DailyGoalDialog(initialGoal: dailyGoal),
    );
    if (!mounted || next == null || next == dailyGoal) return;
    final accountId = loadedAccountId ?? 'guest';
    final todayKey = dateKey(DateTime.now());
    final nextGoals = Map<String, int>.from(practiceGoals)..[todayKey] = next;
    setState(() {
      dailyGoal = next;
      practiceGoals = nextGoals;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setInt(goalKey(accountId), next),
        prefs.setString(goalsKey(accountId), jsonEncode(nextGoals)),
      ]);
    } catch (_) {
      // 현재 실행 중에는 변경한 목표를 유지한다.
    }
  }

  @override
  void dispose() {
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
    final isDark = HomePalette.isDark(context);
    final palette = HomePalette.of(context);
    final background = palette.background;
    final muted = palette.muted;
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final localTheme = base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
      colorScheme:
          (isDark ? const ColorScheme.dark() : const ColorScheme.light())
              .copyWith(
        surface: palette.surface,
        primary: palette.primary,
        onPrimary: isDark ? const Color(0xFF10202F) : Colors.white,
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
                  const SizedBox(height: 20),
                  Row(children: [
                    LearningLanguagePicker(
                      value: language,
                      compact: true,
                      onChanged: (value) => setState(() => language = value),
                    ),
                    const Spacer(),
                    Text('누적 $totalPracticed문장',
                        style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 16),
                  SentenceHistoryDashboard(
                    accountId: accountId,
                    language: language,
                    refreshToken: totalPracticed,
                    onViewAll: () => context.go(AppRoutes.collectionPath),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.learningHubPath),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: palette.onAccent,
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('학습하러 가기',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                      child: Text('따라 말하기부터 반복 듣기까지, 내 방식대로',
                          style: TextStyle(color: muted, fontSize: 12))),
                  const SizedBox(height: 30),
                  TrendingSentencesPreview(
                    language: language,
                    onViewAll: () => context.go(AppRoutes.collectionPath),
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
