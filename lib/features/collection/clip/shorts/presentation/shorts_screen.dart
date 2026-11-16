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
import 'package:parrokit/core/shared/utils/audio_focus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'shorts_texts.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/ad_provider.dart';
import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/shorts_provider.dart';
import 'package:parrokit/core/infrastructure/services/ad_service.dart';

import 'widgets/shorts_page.dart';
import 'widgets/action_rail.dart';
import 'widgets/shorts_top_overlay.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/shorts_progress.dart';

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
  int? _loggedClipId; // 최근 본 클립으로 이미 남긴 클립

  @override
  void initState() {
    super.initState();
    _showSubtitle = AppConfig.shortsShowSubtitles;
    // 쇼츠가 바로 재생되므로 이어 듣던 클립은 멈춘다(5차, 사용자 요청).
    unawaited(AudioFocus.instance.claim());
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
      AdService()
          .showInterstitialAd(); // premium이면 incrementBy가 false를 반환 → 여기 안 옴
      ad.recordAdShown();
      _pauseSignal.value = false;
    }
  }

  /// 지금 보고 있는 클립 하나만 '최근 본 클립'에 남긴다.
  ///
  /// 전에는 itemBuilder 안에서 기록해서, PageView가 미리 만들어 두는 양옆
  /// 페이지와 다시 그릴 때마다 DB에 썼다. 그래서 보지도 않은 클립이 최근
  /// 목록에 올라왔다(5차).
  void _logCurrentClip(int clipId) {
    if (_loggedClipId == clipId) return;
    _loggedClipId = clipId;
    context.read<ClipActivityProvider>().logRecent(clipId);
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
          // 영상이 없을 때는 레터박스 검정 대신 보통 화면색을 쓴다.
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: AppEmptyState(
              icon: Icons.video_library_outlined,
              // 쇼츠는 기기·서버 클립만 읽는다(ShortsRepository). Google Drive
              // 클립만 있는 사람도 왜 안 나오는지 알 수 있게 '만'을 남긴다.
              // 설명은 한 줄로 줄이고, 바로 클립을 만들 수 있게 버튼을 둔다.
              title: '쇼츠로 볼 클립이 없어요',
              description: '기기나 서버에 저장한 클립만 나와요',
              actionLabel: '클립 추가하기',
              onAction: () async {
                await context.pushNamed(AppRoutes.clipsCreate);
                if (!context.mounted) return;
                await context.read<ShortsProvider>().refresh();
              },
            ),
          );
        }

        // removeItems로 목록이 줄어든 프레임에서 _currentIndex가 범위를
        // 넘을 수 있다. 아래에서 그대로 쓰므로 먼저 맞춘다.
        final current = _currentIndex.clamp(0, shorts.shorts.length - 1);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _logCurrentClip(shorts.shorts[current].clip.id);
        });

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
                  return ShortsPage(
                    key: ValueKey(item.clip.id),
                    isActive: index == current,
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
              // 위쪽 겹침 줄: 진행 띠 → 클립 이름 → 태그.
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Builder(builder: (_) {
                    // 클립이 묶음(10개)보다 적으면 그만큼만 그린다. 전에는
                    // 늘 10칸이라 두 개뿐이어도 여덟 개가 남은 듯 보였다(5차).
                    final bar = shortsProgress(
                      currentIndex: current,
                      clipCount: shorts.shorts.length,
                      pageSize: ShortsProvider.pageSize,
                    );
                    final item = shorts.shorts[current];
                    return ShortsTopOverlay(
                      index: bar.index,
                      total: bar.total,
                      title: item.clip.title,
                      tagNames: [for (final tag in item.tags) tag.name],
                    );
                  }),
                ),
              ),
              // Right action rail
              Positioned(
                right: 12,
                // 탐색 줄·자막과 같이 탭 바 위로 올린다.
                bottom: MediaQuery.paddingOf(context).bottom + 120,
                child: ActionRail(
                  autoNextEnabled: shorts.autoNext,
                  // Provider 상태
                  onAutoNextChanged: (enabled) {
                    shorts.setAutoNext(enabled);
                    AppConfig.autoNext = enabled;
                    AppConfig.saveToPrefs();
                  },
                  onOpenExternalPlayer: () {
                    final item = shorts.shorts[current];
                    final clipId = item.clip.id;

                    _pauseSignal.value = true; // 모두 멈춰/해제

                    context.pushNamed(
                      AppRoutes.clipsPlay,
                      queryParameters: {'clipId': clipId.toString()},
                    ).then((_) {
                      // 플레이어를 보는 사이 쇼츠 탭을 떠났으면 해제된
                      // notifier에 쓰게 된다(5차, 같은 종류 여러 번 고침).
                      if (!mounted) return;
                      _pauseSignal.value = false;
                    });
                  },
                  showSubtitle: _showSubtitle,
                  onSubtitleChanged: (enabled) {
                    setState(() {
                      _showSubtitle = enabled;
                    });
                    AppConfig.shortsShowSubtitles = enabled;
                    AppConfig.saveToPrefs();
                    // 자막이 없는 영상에서 켜면 아무 일도 안 일어나 고장처럼
                    // 보였다. 왜 안 보이는지 알린다(5차 354).
                    if (enabled && shorts.shorts[current].segments.isEmpty) {
                      showToast(shortsNoSubtitleHint);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
