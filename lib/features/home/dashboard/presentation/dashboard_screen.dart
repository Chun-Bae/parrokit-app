// ============================================================================
// lib/features/dashboard/presentation/dashboard_screen.dart
// ============================================================================
//
// [역할]
// 대시보드 메인 화면. 앱 홈 화면으로 사용.
// 히어로 카드, 이어보기, 모음집, 랜덤 자막 섹션으로 구성.
//
// [레이어]
// Presentation Layer - View
// ClipActivityProvider를 통해 데이터를 구독하고 표시.
//
// [구성 요소]
// - HeaderSection: 상단 로고 + 클립 수 표시
// - HeroSection: 오늘의 학습 카드
// - ContinueWatchingSection: 이어보기 리스트
// - CollectionsSection: 모음집 그리드
// - RandomSubtitleSection: 랜덤 자막 리스트
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/core/shared/widgets/expandable_action_fab.dart';

import 'sections/header_section.dart';
import 'sections/hero_section.dart';
import 'sections/continue_watching_section.dart';
import 'sections/collections_section.dart';
import 'sections/random_subtitle_section.dart';
import '../../../../core/shared/widgets/tip_dialog.dart';

/// 대시보드 메인 화면 (앱 홈).
///
/// [ClipActivityProvider]를 구독하여 데이터 표시.
/// Pull-to-refresh로 데이터 갱신.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isContentStudioExtended = true;

  // ─────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateContentStudioFabState);
    // 화면 초기 진입 시 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ui = context.read<ClipActivityProvider>();
      ui.refreshRandomSegments();
      ui.refreshRandomHeroClip();
      if (context.mounted) showTipDialog(context);
    });
  }

  void _updateContentStudioFabState() {
    final shouldExtend = _scrollController.offset <= 1.0;
    if (_isContentStudioExtended == shouldExtend) return;
    setState(() => _isContentStudioExtended = shouldExtend);
  }

  /// Pull-to-refresh 핸들러
  Future<void> _onRefresh() async {
    // ✅ async gap 전에 Provider 캡처
    final ui = context.read<ClipActivityProvider>();

    await Future.wait([
      ui.refreshRandomSegments(),
      ui.refreshRandomHeroClip(),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _scrollController.removeListener(_updateContentStudioFabState);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 테마 색상
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceContainer;

    // Provider 구독
    final ui = context.watch<ClipActivityProvider>();

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: bg,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Scaffold.floatingActionButton은 body와 별개 레이어라서 스크롤뷰의
      // 오버스크롤 효과와 겹치는 문제 자체가 생기지 않습니다. AppShell(바깥
      // Scaffold)의 bottomNavigationBar는 extendBody 때문에 이 안쪽
      // Scaffold에 자동 반영되지 않으므로, 그 높이만큼만 직접 띄웁니다.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ExpandableActionFab(
          isExtended: _isContentStudioExtended,
          icon: Icons.auto_awesome_rounded,
          label: '콘텐츠 제작',
          onTap: () => context.go(AppRoutes.contentStudioBridgePath),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          border: Border.all(color: AppColors.dividerSubtle),
          iconSize: 19,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        // FAB 회피용으로 하단에 별도 여백을 예약하지 않습니다 — 그 여백이
        // 네비바가 가리는 높이와 정확히 안 맞으면 대시보드 배경색이 그대로
        // 드러나는 틈이 생겼습니다. 콘텐츠 맨 아래가 FAB와 살짝 겹치는 건
        // floating action button의 정상적인 동작이라 문제 삼지 않습니다.
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ───────────────────────────────────────────────────────────
            // 헤더 섹션 (로고 + 클립 수)
            // ───────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: const HeaderSection(),
                ),
              ),
            ),

            // ───────────────────────────────────────────────────────────
            // 히어로 카드 섹션
            // ───────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: HeroSection(
                  heroClip: ui.heroClip,
                  loading: ui.loadingHero,
                  onTap: () => _navigateToHeroClip(ui.heroClip),
                ),
              ),
            ),

            // ───────────────────────────────────────────────────────────
            // 이어보기 섹션
            // ───────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: ContinueWatchingSection(
                items: ui.recent6,
                onTapItem: (clipId) => context.pushNamed(
                  AppRoutes.clipsPlay,
                  queryParameters: {'clipId': clipId.toString()},
                ),
                onTapMore: () => context.push(AppRoutes.recentsPath),
                onTapLibrary: () => context.goNamed(AppRoutes.collection),
              ),
            ),

            // ───────────────────────────────────────────────────────────
            // 모음집 섹션
            // ───────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: CollectionsSection(collections: ui.collections),
            ),

            // ───────────────────────────────────────────────────────────
            // 랜덤 자막 섹션
            // ───────────────────────────────────────────────────────────
            RandomSubtitleSection(
              segments: ui.randomSegments,
              loading: ui.loadingRandom,
            ),

            // 하단 여백
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }

  /// 히어로 클립 탭 시 네비게이션
  void _navigateToHeroClip((int, dynamic, String?, String?)? hero) {
    if (hero != null) {
      final (clipId, thumbnail, clipTitle, titleName) = hero;
      context.pushNamed(
        AppRoutes.clipsPlay,
        queryParameters: {'clipId': clipId.toString()},
      );
    } else {
      context.go(AppRoutes.collectionPath);
    }
  }
}
