import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';

import 'widgets/study_garden_preview.dart';
import 'widgets/sentence_history_dashboard.dart';
import 'widgets/today_practice_summary.dart';
import 'widgets/trending_sentences_preview.dart';
import 'stage_preview_screen.dart';
import 'tts_test_screen.dart';

/// 성장 UI를 비교하기 위한 별도 화면. 경험치와 퀘스트는 저장되지 않는 예시다.
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
    const background = Color(0xFFF3F8FD);
    const surface = Color(0xFFFFFFFF);
    const ink = Color(0xFF24364F);
    const muted = Color(0xFF61758D);
    const accent = Color(0xFFA8CBE8);
    final localTheme = ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: background,
      textTheme: ThemeData.light().textTheme.apply(
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
      colorScheme: const ColorScheme.light(
          surface: surface,
          primary: Color(0xFF4F6EAF),
          onPrimary: Colors.white,
          onSurface: ink),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
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
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF24364F),
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
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        context.push(AppRoutes.classicDashboardPath),
                    child: Text('기존 대시보드 열기', style: TextStyle(color: muted)),
                  ),
                  if (kDebugMode)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const TtsTestScreen())),
                      child: Text('TTS 테스트 (debug)',
                          style: TextStyle(color: muted)),
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
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF547B91),
                                onPressed: scrollToTop,
                                child: const Icon(
                                    Icons.keyboard_arrow_up_rounded)))))),
          ]),
        ),
      ),
    );
  }
}
