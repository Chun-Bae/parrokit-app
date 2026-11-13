// ============================================================================
// lib/features/_content/shorts/presentation/widgets/shorts_page.dart
// ============================================================================
//
// [역할]
// 쇼츠 화면 내 개별 비디오 페이지 위젯.
//
// [레이어]
// Presentation Layer > Widgets
//
// ============================================================================

import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:parrokit/data/local/app_database.dart'; // Segment 타입 사용
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/widgets/video_layer_placeholder.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/sections/shorts_page_subtitle_section.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/sections/shorts_page_control_section.dart';

enum FitMode { cover, contain }

/// [역할]
/// 쇼츠 리스트의 개별 아이템(비디오)을 표시하는 위젯.
///
/// 화면에 보일 때([isActive])만 비디오를 초기화하고 재생하며,
/// 화면에서 사라지면 리소스를 해제하여 메모리를 최적화합니다.
///
/// [기능]
/// - 로컬 비디오 파일 재생 ([VideoPlayerController])
/// - 제스처 제어 (탭하여 재생/일시정지)
/// - 하위 섹션([ShortsPageSubtitleSection], [ShortsPageControlSection]) 관리
/// - 오디오 루프 및 자동 넘김(AutoNext) 처리
class ShortsPage extends StatefulWidget {
  const ShortsPage({
    super.key,
    required this.clipId,
    required this.filePath, // 절대 경로
    required this.durationMs, // 영상 길이 (ms)
    required this.segments, // 자막 데이터 목록
    required this.onEnded, // 영상 종료 시 콜백
    required this.autoNextEnabled, // 자동 넘김 활성화 여부
    required this.isActive, // 현재 화면 노출 여부
    required this.pauseSignal, // 외부 일시정지 신호
    required this.showSubtilte, // 자막 표시 여부
    this.fitMode = FitMode.contain, // 영상 맞춤 모드
  });

  /// 자동 넘김 활성화 여부. true일 경우 영상 종료 시 [onEnded] 호출.
  final bool autoNextEnabled;

  /// 비디오 파일의 절대 경로.
  final int clipId;

  /// 비디오 파일의 절대 경로.
  final String filePath;

  /// 비디오 길이 (밀리초).
  final int durationMs;

  /// 자막(세그먼트) 리스트.
  final List<Segment> segments;

  /// 현재 이 페이지가 사용자에게 보이고 있는지 여부.
  /// (PageView의 currentIndex와 비교하여 결정됨)
  final bool isActive;

  /// 영상 종료 시 호출되는 콜백. (주로 다음 페이지로 이동)
  final VoidCallback onEnded;

  /// 영상 비율 맞춤 설정 (contain/cover).
  final FitMode fitMode;

  /// 광고 등 외부 요인에 의한 일시정지 신호.
  final ValueListenable<bool> pauseSignal;

  /// 자막 표시 여부 스위치.
  final bool showSubtilte;

  @override
  State<ShortsPage> createState() => _ShortsPageState();
}

class _ShortsPageState extends State<ShortsPage>
    with AutomaticKeepAliveClientMixin {
  // ─────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────
  VideoPlayerController? _controller;
  bool _init = false;
  String? _error;
  bool _active = true;
  String? _resolvedPath;

  /// 동시에 여러 초기화가 겹칠 때를 막는 토큰 (세대 구분)
  int _loadGen = 0;
  bool _isDragging = false;
  bool _wasPlayingBeforeDrag = false;

  @override
  bool get wantKeepAlive => true;

  // ─────────────────────────────────────────────────────────────────
  // Init & Dispose
  // ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _active = widget.isActive;
    widget.pauseSignal.addListener(_onPauseSignalChanged);

    if (_active) {
      _initVideo();
    }
  }

  void _onPauseSignalChanged() {
    final paused = widget.pauseSignal.value;
    if (paused) {
      // 외부로 나갈 때: 즉시 해제
      setActive(false);
    } else {
      // 복귀했을 때: 내가 활성 페이지면 다시 초기화/재생
      if (widget.isActive && (_controller == null || !_init)) {
        setActive(true); // 내부에서 _initVideo 호출
      }
    }
  }

  /// 페이지 활성/비활성 상태를 변경하고 리소스를 관리합니다.
  ///
  /// - [v] == true: 비디오 컨트롤러를 초기화하고 재생을 준비합니다.
  /// - [v] == false: 재생을 중지하고 컨트롤러를 해제(dispose)하여 메모리를 확보합니다.
  /// 상태 변경 시 [_loadGen](세대 토큰)을 증가시켜, 이전 비동기 작업이 현재 상태를 덮어쓰지 않도록 방어합니다.
  Future<void> setActive(bool v) async {
    if (_active == v) return;
    _active = v;

    if (!_active) {
      // 보이지 않으면 완전 해제 (한 번에 하나만 살아 있도록)
      final c = _controller;
      _controller = null;
      _init = false;
      _loadGen++; // 이후 콜백 무효화
      await c?.pause();
      await c?.dispose();
      if (mounted) setState(() {});
      return;
    } else {
      // 다시 보이면 재초기화
      await _initVideo();
    }
  }

  @override
  void didUpdateWidget(covariant ShortsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      setActive(widget.isActive);
    }
    if (oldWidget.pauseSignal != widget.pauseSignal) {
      oldWidget.pauseSignal.removeListener(_onPauseSignalChanged);
      widget.pauseSignal.addListener(_onPauseSignalChanged);
    }
    // autoNext 토글 시 루프 설정 즉시 반영
    if (oldWidget.autoNextEnabled != widget.autoNextEnabled &&
        _controller != null) {
      _controller!.setLooping(!widget.autoNextEnabled);
    }
  }

  /// 비디오 컨트롤러를 생성하고 초기화합니다.
  ///
  /// 1. 파일 경로로부터 컨트롤러 생성
  /// 2. [initialize] 호출
  /// 3. 세대 토큰([_loadGen]) 검사로 초기화 중 상태 변경 감지
  /// 4. 루프 설정 및 자동 재생 시작
  /// 5. 리스너 등록 (재생 위치 모니터링, 자동 넘김 감지)
  Future<void> _initVideo() async {
    final myGen = ++_loadGen;
    try {
      final sourcePath = await _resolveSourcePath();
      if (myGen != _loadGen) return;

      final c = VideoPlayerController.file(File(sourcePath));
      await c.initialize();

      if (myGen != _loadGen) {
        await c.dispose();
        return;
      }

      await c.setLooping(!widget.autoNextEnabled);
      if (_active) await c.play();

      c.addListener(() {
        if (!mounted) return;
        final v = c.value;

        // ✅ 드래그 중에는 onEnded 방지
        if (_active && widget.autoNextEnabled && !_isDragging) {
          final pos = v.position.inMilliseconds;
          final dur = v.duration.inMilliseconds;
          if (dur > 0 && pos >= dur - 300) {
            widget.onEnded();
          }
        }
        setState(() {});
      });

      if (!mounted || myGen != _loadGen) {
        await c.dispose();
        return;
      }

      setState(() {
        _controller = c;
        _init = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '영상을 다시 불러오지 못했어요.');
    }
  }

  Future<String> _resolveSourcePath() async {
    final clipProvider = context.read<ClipProvider>();
    final current = _resolvedPath;
    if (current != null) {
      final currentFile = File(current);
      if (await currentFile.exists() && await currentFile.length() > 0) {
        return current;
      }
    }

    final directFile = File(widget.filePath);
    if (await directFile.exists() && await directFile.length() > 0) {
      _resolvedPath = widget.filePath;
      return widget.filePath;
    }

    final payload = await clipProvider.fetchClipById(widget.clipId);
    final resolved = payload?.clip.filePath;
    if (resolved == null || resolved.isEmpty) {
      throw StateError('재생할 파일을 찾을 수 없습니다.');
    }

    _resolvedPath = resolved;
    return resolved;
  }

  @override
  void dispose() {
    widget.pauseSignal.removeListener(_onPauseSignalChanged);
    _loadGen++;
    _controller?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
    setState(() {});
  }

  Future<void> _seekToFraction(double f) async {
    final c = _controller;
    if (c == null) return;
    final dur = c.value.duration.inMilliseconds > 0
        ? c.value.duration
        : Duration(milliseconds: widget.durationMs);
    final targetMs = (dur.inMilliseconds * f).clamp(0, dur.inMilliseconds);
    await c.seekTo(Duration(milliseconds: targetMs.round()));
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final c = _controller;
    final pos = c?.value.position ?? Duration.zero;

    // 비디오 에러/플레이스홀더/플레이어
    Widget videoLayer() {
      if (_error != null) {
        return Center(
          child: Text(_error!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white)),
        );
      }
      if (!_init || c == null) return const VideoLayerPlaceholder();

      final aspect = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;

      if (widget.fitMode == FitMode.cover) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        );
      } else {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: aspect,
            child: VideoPlayer(c),
          ),
        );
      }
    }

    final currentSeg =
        c != null ? segmentForPosition(widget.segments, pos) : null;
    // 아래 떠 있는 탭 바가 덮는 높이. 예전엔 탐색 줄을 bottom: 0에 두어 탭 바
    // 뒤에 깔려 거의 안 보이고 잡을 수도 없었다(5차).
    final navInset = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // --- Video ---
          videoLayer(),

          // --- Subtitles Section ---
          if (currentSeg != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: navInset + 56,
              child: IgnorePointer(
                child: ShortsPageSubtitleSection(
                  segment: currentSeg,
                  showSubtitle: widget.showSubtilte,
                ),
              ),
            ),

          // --- Center Play 버튼 ---
          if (c != null && !c.value.isPlaying)
            Center(
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _togglePlay,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 36,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

          // --- Control Section (Progress / Seek) ---
          Positioned(
            left: 0,
            right: 0,
            bottom: navInset,
            child: ShortsPageControlSection(
              controller: c,
              durationMs: widget.durationMs,
              onSeek: _seekToFraction,
              onDragStart: () {
                final ctrl = _controller;
                if (ctrl == null) return;
                _wasPlayingBeforeDrag = ctrl.value.isPlaying;
                ctrl.pause();
                setState(() => _isDragging = true);
              },
              onDragEnd: () {
                setState(() => _isDragging = false);
                final ctrl = _controller;
                if (ctrl != null && _wasPlayingBeforeDrag && _active) {
                  ctrl.play();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 현재 재생 위치에 해당하는 Segment 반환
Segment? segmentForPosition(List<Segment> segs, Duration pos) {
  for (final s in segs) {
    final start = Duration(milliseconds: s.startMs);
    final end = Duration(milliseconds: s.endMs);
    if (pos >= start && pos < end) return s;
  }
  return null;
}
