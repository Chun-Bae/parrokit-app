// ============================================================================
// lib/features/shorts/presentation/shorts_screen.dart
// ============================================================================
//
// [역할]
// 쇼츠 화면 (TikTok/Reels 스타일).
// 세로 스와이프로 클립을 넘기며 학습.
//
// [레이어]
// Presentation Layer > Screen
//
// [구성 요소]
// - ShortsPage: 개별 클립 페이지
// - ProgressBar: 상단 진행 바
// - ActionRail: 우측 액션 버튼들
// - Badge: 태그 배지
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/ad_provider.dart';
import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/shorts_provider.dart';
import 'package:parrokit/core/infrastructure/services/ad_service.dart';

import 'widgets/shorts_page.dart';
import 'widgets/progress_bar.dart';
import 'widgets/action_rail.dart';
import 'widgets/shorts_badge.dart';

/// [역할]
/// 쇼츠(Shorts) 기능을 제공하는 메인 화면.
///
/// TikTok이나 Reels와 유사한 세로 스크롤 UX를 제공합니다.
/// - [PageView]를 사용하여 수직 스크롤 구현
/// - [ShortsProvider]를 통해 데이터 로드 및 상태 관리
/// - [AdProvider]를 통해 스와이프 횟수에 따른 광고 노출 제어
/// - [ActionRail], [ProgressBar], [Badge] 등 하위 위젯 배치 및 상호작용
class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenScreenState();
}

class _ShortsScreenScreenState extends State<ShortsScreen> {
  // ─────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────
  final PageController _pageController = PageController();
  final ValueNotifier<bool> _pauseSignal = ValueNotifier<bool>(false);
  int _currentIndex = 0; // 현재 보는 클립 인덱스
  bool _showSubtitle = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _showSubtitle = AppConfig.shortsShowSubtitles;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<ShortsProvider>().setAutoNext(AppConfig.autoNext);
      context.read<ShortsProvider>().loadInitial();
    });
  }

  /// 페이지 이동 시 광고 노출 여부를 체크하고 실행하는 메소드.
  ///
  /// [oldIndex]와 [newIndex]의 차이를 계산하여 앞으로 이동한 경우([delta] > 0)에만 카운트합니다.
  /// [AdProvider.incrementBy]가 true를 반환하면 광고를 노출합니다.
  /// 광고 노출 전후로 [_pauseSignal]을 통해 비디오 재생을 일시 정지/재개합니다.
  void _maybeShowAdOnAdvance(BuildContext context, int oldIndex, int newIndex) {
    // 뒤로/같은 페이지는 무시, 앞으로 N칸 이동만 카운트
    final delta = newIndex - oldIndex;
    if (delta <= 0) return;

    final ad = context.read<AdProvider>();
    final shouldShow = ad.incrementBy(delta); // 내부에서 premium/모듈연산/저장 처리

    if (shouldShow) {
      _pauseSignal.value = true;
      AdService().showInterstitialAd(); // premium이면 incrementBy가 false를 반환 → 여기 안 옴
      ad.recordAdShown();
      _pauseSignal.value = false;
    }
  }

  @override
  void dispose() {
    _pauseSignal.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<ShortsProvider>(
      builder: (_, shorts, __) {
        if (shorts.loading && shorts.shorts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (shorts.shorts.isEmpty) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Center(
              child: Text(
                '아직 등록된 클립이 없어요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: shorts.shorts.length,
                onPageChanged: (i) {
                  // 초기 호출 한 번은 무시
                  if (!_initialized) {
                    _initialized = true;
                  } else {
                    _maybeShowAdOnAdvance(context, _currentIndex, i);
                  }

                  unawaited(
                    context.read<ShortsProvider>().prefetchNextBatch(i),
                  );

                  // 2. 10번째(인덱스 10) 이상으로 넘어갔을 때 → Cycle Refresh
                  // 0~9(10개)가 지나고 10(11번째, 다음 배치의 첫 번째)에 도달하면
                  // 앞의 10개를 지우고 인덱스를 0으로 점프시킴.
                  const batchSize = ShortsProvider.pageSize;
                  if (i >= batchSize) {
                    // (1) 데이터 정리: 앞의 10개 삭제
                    shorts.removeItems(batchSize);

                    // (2) 화면 점프: 현재 i에서 10을 뺀 위치로 이동 (i=10 -> 0)
                    // jumpToPage는 즉시 반영되므로 끊김 없이 보임
                    final newIndex = i - batchSize;
                    _pageController.jumpToPage(newIndex);

                    // (3) 상태 업데이트
                    setState(() => _currentIndex = newIndex);
                  } else {
                    // 평범한 이동
                    setState(() => _currentIndex = i);
                  }
                },
                itemBuilder: (context, index) {
                  final item = shorts.shorts[index];
                  context
                      .read<ClipActivityProvider>()
                      .logRecent(item.clip.id); // 최근 본 클립 기록

                  return ShortsPage(
                    key: ValueKey(item.clip.id),
                    isActive: index == _currentIndex,
                    clipId: item.clip.id,
                    filePath: item.clip.filePath,
                    durationMs: item.clip.durationMs,
                    autoNextEnabled: shorts.autoNext,
                    segments: item.segments,
                    pauseSignal: _pauseSignal,
                    showSubtilte: _showSubtitle,
                    onEnded: () {
                      final sp = context.read<ShortsProvider>();

                      final isLast = index >= shorts.shorts.length - 1;
                      if (!sp.autoNext || isLast) return;
                      if (_pageController.hasClients &&
                          _pageController.page?.round() == index) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutQuart,
                        );
                      }
                    },
                  );
                },
              ),
              // Top progress (story-like)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: ProgressBar(
                      // 항상 10개를 기준으로 보여줌 (20개가 있어도 UI는 10개 사이클)
                      index: _currentIndex % ShortsProvider.pageSize,
                      total: ShortsProvider.pageSize,
                    ),
                  ),
                ),
              ),

              // Right action rail
              Positioned(
                right: 12,
                bottom: 110,
                child: ActionRail(
                  autoNextEnabled: shorts.autoNext,
                  // Provider 상태
                  onAutoNextChanged: (enabled) {
                    shorts.setAutoNext(enabled);
                  },
                  onOpenExternalPlayer: () {
                    final item = shorts.shorts[_currentIndex];
                    final clipId = item.clip.id;

                    _pauseSignal.value = true; // 모두 멈춰/해제

                    context.pushNamed(
                      AppRoutes.clipsPlay,
                      queryParameters: {'clipId': clipId.toString()},
                    ).then((_) {
                      _pauseSignal.value = false;
                    });
                  },
                  showSubtitle: _showSubtitle,
                  onSubtitleChanged: (enabled) {
                    setState(() {
                      _showSubtitle = enabled;
                    });
                  },
                ),
              ),

              // Branding badges
              Positioned(
                left: 12,
                top: 12 + MediaQuery.of(context).padding.top,
                child: Row(
                  children: [
                    for (final tag in shorts.shorts[_currentIndex].tags)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ShortsBadge(
                          label: tag.name,
                          icon: Icons.star_border_rounded,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
