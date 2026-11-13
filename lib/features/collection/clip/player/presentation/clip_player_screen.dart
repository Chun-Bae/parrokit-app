// ============================================================================
// lib/features/player/presentation/clip_player_screen.dart
// ============================================================================
//
// [역할]
// 클립 플레이어 화면 (MVVM 패턴).
// ViewModel에서 상태와 로직을 관리하고, View는 UI만 담당.
//
// [레이어]
// Presentation Layer - View
//
// [구성 요소]
// - ClipPlayerViewModel: 상태 및 로직 관리
// - SegmentTimeline, SegmentList, CircleIconButton 등: UI 위젯
// ============================================================================

import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/features/collection/clip/player/domain/player_state.dart';

import 'clip_player_view_model.dart';
import 'widgets/circle_icon_button.dart';
import 'widgets/segment_timeline.dart';
import 'widgets/toggle_pill.dart';
import 'widgets/segment_list.dart';
import 'widgets/speed_menu.dart';
import 'widgets/subtitle_overlay.dart';

/// 클립 플레이어 화면.
///
/// [ClipPlayerViewModel]을 ChangeNotifierProvider로 주입하고,
/// [_ClipPlayerView]에서 UI를 렌더링.
class ClipPlayerScreen extends StatelessWidget {
  const ClipPlayerScreen({
    super.key,
    required this.clipId,
    this.initialIndex = 0,
  });

  final int clipId;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ClipPlayerViewModel(
        clipId: clipId,
        clipProvider: ctx.read<ClipProvider>(),
        initialIndex: initialIndex,
      ),
      child: _ClipPlayerView(clipId: clipId),
    );
  }
}

/// 플레이어 View (ViewModel 구독).
class _ClipPlayerView extends StatefulWidget {
  const _ClipPlayerView({required this.clipId});

  final int clipId;

  @override
  State<_ClipPlayerView> createState() => _ClipPlayerViewState();
}

class _ClipPlayerViewState extends State<_ClipPlayerView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 최근 본 클립 기록
    Future.microtask(() {
      if (!mounted) return;
      context.read<ClipActivityProvider>().logRecent(widget.clipId);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final vm = context.read<ClipPlayerViewModel>();
    vm.handleAppLifecycleChange(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClipPlayerViewModel>();
    final t = Theme.of(context);
    final cs = t.colorScheme;

    // 테마 색상 (항상 light 모드로 고정)
    const isLight = true;
    final bg = cs.surface;
    final fg = cs.onSurface;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // 로딩 상태
    if (vm.isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: fg,
          title: const Text('재생'),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: cs.primary,
          ),
        ),
      );
    }

    // 클립 없음
    if (vm.errorMessage != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: fg,
          title: const Text('재생'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              vm.errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (vm.clip == null || vm.segments.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: fg,
          title: const Text('재생'),
        ),
        body: const Center(child: Text('클립을 찾을 수 없습니다.')),
      );
    }

    return Scaffold(
      backgroundColor: vm.isFullscreen ? Colors.black : bg,
      appBar: vm.isFullscreen
          ? null
          : AppBar(
              backgroundColor: bg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              foregroundColor: fg,
              title: Text(vm.appBarTitle),
              // 플레이어에서 바로 고친다(5차). 예전엔 목록에서 밀어야만 '편집'이
              // 보여서, 보다가 고칠 데를 찾으면 나갔다가 다시 찾아야 했다.
              actions: [
                if (vm.clip != null)
                  IconButton(
                    key: const ValueKey('player-edit'),
                    tooltip: '편집',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      vm.controller?.pause();
                      final changed = await context.push<bool>(
                          '${AppRoutes.clipsPath}/${AppRoutes.clipsEditPath}'
                          '?clipId=${widget.clipId}');
                      if (changed == true && context.mounted) {
                        await vm.reloadAfterEdit();
                      }
                    },
                  ),
              ],
            ),
      body: vm.isFullscreen
          ? _buildFullscreenBody(context, vm, isLight)
          : isLandscape
              ? _buildLandscapeBody(context, vm, bg, fg, isLight)
              : _buildPortraitBody(context, vm, bg, fg, isLight),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Fullscreen Body
  // ─────────────────────────────────────────────────────────────────

  Widget _buildFullscreenBody(
    BuildContext context,
    ClipPlayerViewModel vm,
    bool isLight,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        vm.showOverlayTemporarily();
        vm.playPause();
      },
      child: Builder(builder: (context) {
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;
        return RotatedBox(
          quarterTurns: isPortrait ? 1 : 0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 비디오
              Positioned.fill(
                child: vm.isBackground
                    ? Container(color: Colors.black)
                    : Builder(builder: (context) {
                        final controller = vm.controller;
                        if (controller == null) {
                          return Container(color: Colors.black);
                        }
                        return FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        );
                      }),
              ),

              // 자막
              if (vm.showSubtitles)
                SubtitleOverlay(
                  ja: vm.currentSegment.original,
                  pron: vm.currentSegment.pron,
                  ko: vm.currentSegment.trans,
                ),

              // 풀스크린 토글
              Positioned(
                right: 12,
                bottom: 12,
                child: AnimatedOpacity(
                  opacity: vm.overlayVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !vm.overlayVisible,
                    child: IconButton(
                      tooltip: '전체 화면 끝내기',
                      icon: const Icon(Icons.fullscreen_exit),
                      color: Colors.white,
                      onPressed: vm.toggleFullscreen,
                    ),
                  ),
                ),
              ),

              // 닫기 버튼
              Positioned(
                right: 12,
                top: 12,
                child: AnimatedOpacity(
                  opacity: vm.overlayVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !vm.overlayVisible,
                    child: Builder(builder: (context) {
                      final isPortrait = MediaQuery.of(context).orientation ==
                          Orientation.portrait;
                      return Transform.rotate(
                        angle: isPortrait ? math.pi / 2 : 0.0,
                        child: IconButton(
                          tooltip: '전체 화면 닫기',
                          icon: const Icon(Icons.close),
                          color: Colors.white,
                          onPressed: vm.toggleFullscreen,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Landscape Body
  // ─────────────────────────────────────────────────────────────────

  Widget _buildLandscapeBody(
    BuildContext context,
    ClipPlayerViewModel vm,
    Color bg,
    Color fg,
    bool isLight,
  ) {
    final cs = Theme.of(context).colorScheme;
    final controller = vm.controller;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 왼쪽: 영상 + 타임라인 + 컨트롤
        Expanded(
          child: Column(
            children: [
              // Video
              Flexible(
                flex: 3,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller?.value.aspectRatio == 0
                        ? 16 / 9
                        : controller?.value.aspectRatio ?? 16 / 9,
                    child: _buildVideoStack(context, vm, isLight),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Timeline
              if (controller != null)
                IgnorePointer(
                  ignoring: vm.isBackground,
                  child: SegmentTimeline(
                    controller: controller,
                    start: Duration(milliseconds: vm.currentSegment.startMs),
                    end: Duration(milliseconds: vm.currentSegment.endMs),
                    onSeek: vm.seekTo,
                  ),
                ),
              const SizedBox(height: 8),

              // Controls
              _buildControls(context, vm, isLight),
            ],
          ),
        ),

        // 오른쪽: 세그먼트 리스트
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                color: cs.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: IgnorePointer(
            ignoring: vm.isBackground,
            child: Opacity(
              opacity: vm.isBackground ? 0.4 : 1.0,
              child: SegmentList(
                segments: vm.segments,
                currentIndex: vm.segIndex,
                onTapItem: (i) => vm.jumpToSegment(i, autoplay: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Portrait Body
  // ─────────────────────────────────────────────────────────────────

  Widget _buildPortraitBody(
    BuildContext context,
    ClipPlayerViewModel vm,
    Color bg,
    Color fg,
    bool isLight,
  ) {
    final controller = vm.controller;
    final ar = controller?.value.aspectRatio ?? 0;
    final displayAr = ar == 0 ? 16.0 / 9.0 : ar;
    final isPortraitVideo = displayAr < 1.0;

    return Column(
      children: [
        // Video + Subs
        // 세로 영상은 16:9 높이 박스 안에 중앙 배치(pillarbox),
        // 가로 영상은 원래 비율 그대로 표시.
        if (isPortraitVideo)
          AspectRatio(
            aspectRatio: 16.0 / 9.0,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: displayAr,
                  child: _buildVideoStack(context, vm, isLight),
                ),
              ),
            ),
          )
        else
          AspectRatio(
            aspectRatio: displayAr,
            child: _buildVideoStack(context, vm, isLight),
          ),

        // Timeline
        if (controller != null)
          IgnorePointer(
            ignoring: vm.isBackground,
            child: SegmentTimeline(
              controller: controller,
              start: Duration(milliseconds: vm.currentSegment.startMs),
              end: Duration(milliseconds: vm.currentSegment.endMs),
              onSeek: vm.seekTo,
            ),
          ),
        const SizedBox(height: 8),

        // Controls
        _buildControls(context, vm, isLight),
        const SizedBox(height: 8),

        // Segments List
        Expanded(
          child: IgnorePointer(
            ignoring: vm.isBackground,
            child: Opacity(
              opacity: vm.isBackground ? 0.4 : 1.0,
              child: SegmentList(
                segments: vm.segments,
                currentIndex: vm.segIndex,
                onTapItem: (i) => vm.jumpToSegment(i, autoplay: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Shared Widgets
  // ─────────────────────────────────────────────────────────────────

  Widget _buildVideoStack(
    BuildContext context,
    ClipPlayerViewModel vm,
    bool isLight,
  ) {
    final controller = vm.controller;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              vm.showOverlayTemporarily();
              vm.playPause();
            },
            child: vm.isBackground
                ? Container(color: Colors.black)
                : controller != null
                    ? VideoPlayer(controller)
                    : Container(color: Colors.black),
          ),
        ),

        // 자막
        if (vm.showSubtitles)
          SubtitleOverlay(
            ja: vm.currentSegment.original,
            pron: vm.currentSegment.pron,
            ko: vm.currentSegment.trans,
          ),

        // 풀스크린 토글. 자막이 영상 아래쪽에 깔리므로 위쪽에 둔다. 전에는
        // 오른쪽 아래라서 긴 자막의 마지막 글자 위에 아이콘이 겹쳤다.
        Positioned(
          right: 4,
          top: 4,
          child: AnimatedOpacity(
            opacity: vm.overlayVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !vm.overlayVisible,
              child: IconButton(
                tooltip: vm.isFullscreen ? '전체 화면 끝내기' : '전체 화면',
                icon: Icon(
                  vm.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
                color: Colors.white,
                onPressed: vm.toggleFullscreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(
    BuildContext context,
    ClipPlayerViewModel vm,
    bool isLight,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          // 재생 컨트롤
          Row(mainAxisSize: MainAxisSize.min, children: [
            IgnorePointer(
              ignoring: vm.isBackground,
              child: Opacity(
                opacity: vm.isBackground ? 0.4 : 1.0,
                child: CircleIconButton(
                  icon: Icons.skip_previous_rounded,
                  onTap: vm.prevSegment,
                  tooltip: '이전 구간',
                  isLight: isLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleIconButton(
              icon: (vm.isBackground ? vm.bgPlaying : vm.isPlaying)
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onTap: vm.playPause,
              tooltip: (vm.isBackground ? vm.bgPlaying : vm.isPlaying)
                  ? '일시정지'
                  : '재생',
              emphasized: true,
              isLight: isLight,
              bg: Colors.transparent,
            ),
            const SizedBox(width: 8),
            IgnorePointer(
              ignoring: vm.isBackground,
              child: Opacity(
                opacity: vm.isBackground ? 0.4 : 1.0,
                child: CircleIconButton(
                  icon: Icons.skip_next_rounded,
                  onTap: vm.nextSegment,
                  tooltip: '다음 구간',
                  isLight: isLight,
                ),
              ),
            ),
          ]),

          // 토글 버튼들. 예전엔 가로 한 줄 스크롤이라 '백그라운드'가 잘리고
          // 속도 버튼은 화면 밖이라 있는 줄도 몰랐다(5차). 넘치면 다음 줄로.
          Wrap(
            key: const ValueKey('player-toggles'),
            spacing: 8,
            runSpacing: 8,
            children: [
              // 구간/전체: 예전에는 알약 하나가 글자('구간'/'전체재생')와 켜짐
              // 색(전체일 때만)을 따로 바꿔 지금 무엇인지 헷갈렸다. 두 칸으로
              // 나눠 지금 고른 쪽만 칠한다.
              IgnorePointer(
                ignoring: vm.isBackground,
                child: Opacity(
                  opacity: vm.isBackground ? 0.4 : 1.0,
                  child: _ScopeSwitch(
                    full: vm.scope == PlayScope.full,
                    onChanged: (full) {
                      if (full != (vm.scope == PlayScope.full)) {
                        vm.toggleScope();
                      }
                    },
                    isLight: isLight,
                  ),
                ),
              ),
              // 한 줄씩 멈춤은 전체 재생에서만 뜻이 있다(구간 재생은 줄 끝에서
              // 반복하거나 멈춘다). 구간일 때는 흐리게 두고 누를 수 없다.
              IgnorePointer(
                ignoring: vm.isBackground || vm.scope != PlayScope.full,
                child: Opacity(
                  opacity:
                      vm.isBackground || vm.scope != PlayScope.full ? 0.4 : 1.0,
                  child: TogglePill(
                    key: const ValueKey('pause-each-line'),
                    icon: Icons.pause_circle_outline_rounded,
                    label: '한 줄씩 멈춤',
                    active: vm.pauseEachLine,
                    onTap: vm.togglePauseEachLine,
                    isLight: isLight,
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: vm.isBackground,
                child: Opacity(
                  opacity: vm.isBackground ? 0.4 : 1.0,
                  child: TogglePill(
                    icon: Icons.repeat_rounded,
                    label: '반복',
                    active: vm.loopSegment,
                    onTap: vm.toggleLoop,
                    isLight: isLight,
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: vm.isBackground,
                child: Opacity(
                  opacity: vm.isBackground ? 0.4 : 1.0,
                  child: TogglePill(
                    icon: Icons.subtitles_rounded,
                    label: '자막',
                    active: vm.showSubtitles,
                    onTap: vm.toggleSubtitles,
                    isLight: isLight,
                  ),
                ),
              ),
              TogglePill(
                icon: Icons.headphones_rounded,
                label: '백그라운드',
                active: vm.isBackground,
                onTap: vm.toggleAudioOnlyMode,
                isLight: isLight,
              ),
              IgnorePointer(
                ignoring: vm.isBackground,
                child: Opacity(
                  opacity: vm.isBackground ? 0.4 : 1.0,
                  child: SpeedMenu(
                    value: vm.playbackRate,
                    onSelected: vm.setPlaybackRate,
                    isLight: isLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 구간 | 전체 두 칸. 고른 쪽만 칠한다. 모양은 옆 알약 버튼(TogglePill)에 맞춘다.
class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({
    required this.full,
    required this.onChanged,
    required this.isLight,
  });

  final bool full;
  final ValueChanged<bool> onChanged;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trackColor =
        isLight ? cs.surface.withValues(alpha: 0.9) : Colors.white12;

    Widget cell(String label, bool value) {
      final selected = full == value;
      final fg = selected
          ? (isLight ? cs.primary : Colors.white)
          : (isLight ? cs.onSurface : Colors.white70);
      return Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.full),
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected
                  ? (isLight ? cs.primary.withValues(alpha: 0.14) : Colors.white24)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('play-scope-switch'),
      // 흰 바탕에서 고르지 않은 '구간' 칸이 떠 보이지 않게 옅은 테두리로 묶는다.
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
            color: isLight ? cs.outlineVariant : Colors.white24, width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        cell('구간', false),
        cell('전체', true),
      ]),
    );
  }
}
