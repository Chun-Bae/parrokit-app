import 'dart:async';
// ============================================================================
// lib/features/player/presentation/clip_player_view_model.dart
// ============================================================================
//
// [역할]
// 클립 플레이어 ViewModel (MVVM 패턴).
// 플레이어 상태 관리 및 비즈니스 로직 담당.
//
// [구성]
// - PlaybackControlMixin: 재생 제어, 세그먼트 탐색
// - AudioModeMixin: 오디오 전용 모드
// - UiControlMixin: 풀스크린, 오버레이
//
// [레이어]
// Presentation Layer - ViewModel
// ============================================================================

import 'package:parrokit/core/shared/utils/user_error_message.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/shared/utils/audio_bg.dart';
import 'package:parrokit/core/state/provider/background_playback_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/player/domain/player_state.dart';

import 'line_pause_gate.dart';
import 'view_model/playback_control_mixin.dart';
import 'view_model/audio_mode_mixin.dart';
import 'view_model/ui_control_mixin.dart';

/// 클립 플레이어 ViewModel.
///
/// 비디오/오디오 재생 상태, 세그먼트 탐색, UI 상태를 관리.
class ClipPlayerViewModel extends ChangeNotifier
    with PlaybackControlMixin, AudioModeMixin, UiControlMixin {
  ClipPlayerViewModel({
    required this.clipId,
    required this.clipProvider,
    this.background,
    this.initialIndex = 0,
  }) {
    _init();
  }

  // ─────────────────────────────────────────────────────────────────
  // Dependencies
  // ─────────────────────────────────────────────────────────────────

  final int clipId;
  final ClipProvider clipProvider;

  /// 화면을 나가도 소리를 이어 가는 곳. 없으면 나갈 때 그냥 멈춘다(테스트).
  final BackgroundPlaybackProvider? background;
  final int initialIndex;

  /// 영상 파일의 절대 경로. 나갈 때 소리로 넘기려면 그때 다시 찾을 수 없어
  /// 미리 들고 있는다(dispose는 기다릴 수 없다).
  String _resolvedPath = '';

  /// 표지 그림. 같은 까닭으로 미리 들고 있는다.
  Uri? _resolvedArtUri;

  /// 이어 듣다가 다시 들어왔을 때 돌아갈 자리.
  Duration? _resumeFrom;

  // ─────────────────────────────────────────────────────────────────
  // State - Core
  // ─────────────────────────────────────────────────────────────────

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isInitialized = false;
  @override
  bool get isInitialized => _isInitialized;

  Clip? _clip;
  @override
  Clip? get clip => _clip;

  List<Segment> _segments = const [];
  @override
  List<Segment> get segments => _segments;

  String _appBarTitle = '재생';
  String get appBarTitle => _appBarTitle;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─────────────────────────────────────────────────────────────────
  // State - Playback
  // ─────────────────────────────────────────────────────────────────

  VideoPlayerController? _controller;
  @override
  VideoPlayerController? get controller => _controller;

  PlayScope _scope = PlayScope.segment;
  @override
  PlayScope get scope => _scope;

  int _segIndex = 0;
  @override
  int get segIndex => _segIndex;

  @override
  Segment get currentSegment => _segments[_segIndex];

  bool _loopSegment = true;
  @override
  bool get loopSegment => _loopSegment;

  bool _showSubtitles = true;
  @override
  bool get showSubtitles => _showSubtitles;

  double _playbackRate = 1.0;
  @override
  double get playbackRate => _playbackRate;

  /// 전체 재생에서 자막 한 줄이 끝날 때마다 멈출지. 기기에 기억한다.
  bool _pauseEachLine = false;
  bool get pauseEachLine => _pauseEachLine;
  final LinePauseGate _lineGate = LinePauseGate();

  void togglePauseEachLine() {
    _pauseEachLine = !_pauseEachLine;
    AppConfig.pauseEachLine = _pauseEachLine;
    AppConfig.saveToPrefs();
    _lineGate.reset();
    notifyListeners();
  }

  bool get isPlaying =>
      _controller?.value.isInitialized == true &&
      _controller?.value.isPlaying == true;

  // ─────────────────────────────────────────────────────────────────
  // State - Audio Only Mode
  // ─────────────────────────────────────────────────────────────────

  bool _isBackground = false;
  @override
  bool get isBackground => _isBackground;

  bool _bgPlaying = false;
  @override
  bool get bgPlaying => _bgPlaying;

  // ─────────────────────────────────────────────────────────────────
  // Mixin Setters
  // ─────────────────────────────────────────────────────────────────

  @override
  set mutableSegIndex(int value) => _segIndex = value;

  @override
  set mutableScope(PlayScope value) {
    _scope = value;
    AppConfig.segmentLoop = value == PlayScope.full;
    AppConfig.saveToPrefs();
  }

  @override
  set mutableLoopSegment(bool value) {
    _loopSegment = value;
    AppConfig.repeatAll = value;
    AppConfig.saveToPrefs();
  }

  @override
  set mutableShowSubtitles(bool value) {
    _showSubtitles = value;
    AppConfig.showSubtitles = value;
    AppConfig.saveToPrefs();
  }

  @override
  set mutablePlaybackRate(double value) {
    _playbackRate = value;
    AppConfig.defaultPlaybackRate = value;
    AppConfig.saveToPrefs();
  }

  @override
  set mutableBgPlaying(bool value) => _bgPlaying = value;

  @override
  set mutableIsBackground(bool value) => _isBackground = value;

  // ─────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────

  void _init() {
    _segIndex = initialIndex;
    _scope = AppConfig.segmentLoop ? PlayScope.full : PlayScope.segment;
    _loopSegment = AppConfig.repeatAll;
    _showSubtitles = AppConfig.showSubtitles;
    _playbackRate = AppConfig.defaultPlaybackRate;
    _pauseEachLine = AppConfig.pauseEachLine;

    loadClip();
  }

  /// 화면을 닫아 dispose된 뒤인지. 로드 중에 뒤로 가면 await 뒤 코드가 이어
  /// 돌아서, 닫힌 화면에 네이티브 플레이어를 새로 만들어 놓지 못하고 남기거나
  /// dispose된 notifier를 다시 알렸다(5차).
  bool _disposed = false;

  /// 클립 데이터 로드.
  Future<void> loadClip() async {
    try {
      // 이어 듣던 클립을 다시 열었으면 소리를 멈추고 들은 자리를 받는다(5차).
      final handOff = background;
      Duration? resumeFrom;
      if (handOff != null && handOff.current?.clipId == clipId) {
        resumeFrom = await handOff.handBack();
      } else if (handOff != null && handOff.isActive) {
        // 다른 클립을 열면 듣던 것은 멈춘다. 둘이 같이 나지 않게.
        await handOff.stop();
      }
      if (_disposed) return;
      _resumeFrom = resumeFrom;
      final payload = await clipProvider.fetchClipById(clipId);
      if (_disposed) return;

      if (payload == null) {
        _errorMessage = '클립을 찾을 수 없어요.';
        _isLoading = false;
        _clip = null;
        _segments = const [];
        notifyListeners();
        return;
      }

      _errorMessage = null;
      _clip = payload.clip;
      _segments = payload.segments;

      await _initVideo();
      if (_disposed) return;

      _isLoading = false;
      _isInitialized = true;
      _appBarTitle = (_clip?.title ?? '').isNotEmpty ? _clip!.title : '재생';
      notifyListeners();
    } catch (e) {
      if (_disposed) return; // dispose가 컨트롤러를 이미 놓았다.
      // _initVideo가 컨트롤러를 만든 뒤 initialize()에서 넘어졌을 수 있다.
      // 그대로 두면 오류 화면을 띄워 둔 내내 네이티브 플레이어를 붙잡고 있다.
      _disposeController();
      // 예외 원문을 보였다(5차). 원문은 로그로.
      AppLogger.e('클립 열기 실패', error: e);
      _errorMessage = userErrorMessage(e,
          fallback: '클립을 열지 못했어요. 영상 파일이 지워졌거나 아직 받지 못했을 수 있어요.');
      _isLoading = false;
      _clip = null;
      _segments = const [];
      notifyListeners();
    }
  }

  /// 편집 화면에서 돌아온 뒤 바뀐 제목·구간·영상을 다시 읽는다(5차). 쓰던
  /// 컨트롤러를 먼저 놓아 플레이어가 둘 붙잡히지 않게 한다.
  Future<void> reloadAfterEdit() async {
    _disposeController();
    _isLoading = true;
    notifyListeners();
    await loadClip();
  }

  /// 컨트롤러를 놓는다. 초기화에 성공했는지와 무관하게 부를 수 있다.
  void _disposeController() {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    _isInitialized = false;
    controller.removeListener(_onTick);
    controller.dispose();
  }

  Future<void> _initVideo() async {
    if (_clip == null) return;

    final resolvedPath = await resolvedSourcePath();
    if (_disposed) return;
    _resolvedPath = resolvedPath;
    // 표지는 없어도 재생에 지장이 없다. 나갈 때 쓰려고 미리 찾아 둔다.
    resolvedThumbUri().then((uri) => _resolvedArtUri = uri).catchError((_) {
      _resolvedArtUri = null;
      return null;
    });
    final controller = VideoPlayerController.file(File(resolvedPath));
    _controller = controller;

    // 기다리는 사이 dispose나 다시 읽기가 이 컨트롤러를 놓았으면 그만둔다.
    bool released() => _disposed || !identical(_controller, controller);

    await controller.initialize();
    if (released()) return;
    await controller.setLooping(false);
    if (released()) return;
    await controller.setPlaybackSpeed(_playbackRate);
    if (released()) return;

    if (_segments.isNotEmpty) {
      _segIndex = _segIndex.clamp(0, _segments.length - 1);
      // 이어 듣다 들어왔으면 그 자리부터, 아니면 구간 처음부터.
      final resume = _resumeFrom;
      _resumeFrom = null;
      await controller.seekTo(
          resume ?? Duration(milliseconds: currentSegment.startMs));
      if (released()) return;
    }

    controller.addListener(_onTick);

    // 나갈 때가 되어서야 소리를 읽으면 한 템포 쉰다. 보고 있는 동안 미리
    // 읽어 둔다(5차, 사용자 신고).
    unawaited(_prepareBackground());
  }

  /// 나가면 틀 소리를 미리 읽어 둔다. 지금 보고 있는 구간·속도 그대로.
  Future<void> _prepareBackground() async {
    final bg = background;
    if (bg == null || _clip == null || _resolvedPath.isEmpty) return;
    if (_isBackground) return; // 이미 소리로 듣는 중이면 건드리지 않는다
    final segmentScope = _scope == PlayScope.segment && _segments.isNotEmpty;
    await bg.prepare(
      absolutePath: _resolvedPath,
      speed: _playbackRate,
      clipBegin:
          segmentScope ? Duration(milliseconds: currentSegment.startMs) : null,
      clipEnd:
          segmentScope ? Duration(milliseconds: currentSegment.endMs) : null,
      loop: _loopSegment,
    );
  }

  void _onTick() {
    if (_controller?.value.isInitialized != true || _segments.isEmpty) return;
    final pos = _controller!.value.position;

    final start = Duration(milliseconds: currentSegment.startMs);
    final end = Duration(milliseconds: currentSegment.endMs);

    if (_scope == PlayScope.segment) {
      if (pos >= end) {
        if (_loopSegment) {
          _controller!.seekTo(start);
          _controller!.play();
        } else {
          _controller!.pause();
          _controller!.seekTo(end);
        }
      }
      if (pos < start && _controller!.value.isPlaying) {
        _controller!.seekTo(start);
      }
    } else {
      // 한 줄씩 멈춤: 지금 줄이 끝나면 한 번 멈춘다. 다시 재생하면 이어서 간다.
      if (_pauseEachLine &&
          _controller!.value.isPlaying &&
          _lineGate.shouldPause(_segIndex, pos, end)) {
        _controller!.pause();
      }
      final idx = indexForPosition(pos);
      if (idx != null && idx != _segIndex) {
        _segIndex = idx;
      }
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────

  /// 앱 생명주기 변화 처리.
  /// 앱을 내렸을 때 보던 영상이 틀어져 있었는지. 돌아오면 그대로 이어 준다.
  bool _wasPlayingBeforeBackground = false;

  /// 앱을 내리면 소리를 이어서 틀고, 돌아오면 영상으로 되돌린다(5차, 사용자 요청).
  ///
  /// 전에는 '소리만 듣기' 버튼을 눌러 둔 사람만 소리가 이어졌다. 누르지 않았으면
  /// 앱을 내리는 순간 멈췄다. 유튜브처럼 알아서 이어지게 한다.
  Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    if (!_isInitialized || _clip == null || _segments.isEmpty) return;

    if (state == AppLifecycleState.paused) {
      if (_isBackground) return;
      final playing = _controller?.value.isInitialized == true &&
          _controller!.value.isPlaying;
      _wasPlayingBeforeBackground = playing;
      if (!playing) return;
      // 영상은 멈추고 소리만 이어 간다. enterAudioOnlyMode가 지금 위치부터 튼다.
      await enterAudioOnlyMode(autoPlay: true);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (!_isBackground || !_wasPlayingBeforeBackground) return;
      _wasPlayingBeforeBackground = false;
      await exitAudioOnlyMode();
      if (_controller?.value.isInitialized == true) {
        await _controller!.play();
      }
    }
  }

  /// 화면을 나갈 때 소리를 앱에 넘긴다. 넘겼으면 true.
  ///
  /// dispose는 기다릴 수 없으므로 필요한 값(경로·위치·속도)을 먼저 읽어
  /// 넘기고, 실제 재생은 provider가 이어서 한다(5차, 사용자 요청).
  bool _handOffToBackground() {
    final handOff = background;
    final clip = _clip;
    if (handOff == null || clip == null || _resolvedPath.isEmpty) return false;

    final playingVideo = _controller?.value.isInitialized == true &&
        _controller!.value.isPlaying;
    // 앱을 내렸다가 바로 화면을 닫은 경우에도 소리는 이어 간다.
    if (!playingVideo && !_isBackground) return false;

    final position = _controller?.value.isInitialized == true
        ? _controller!.value.position
        : Duration(milliseconds: currentSegment.startMs);

    unawaited(handOff.takeOver(
      clipId: clipId,
      title: clip.title,
      absolutePath: _resolvedPath,
      position: position,
      speed: _playbackRate,
      clipBegin: _scope == PlayScope.segment
          ? Duration(milliseconds: currentSegment.startMs)
          : null,
      clipEnd: _scope == PlayScope.segment
          ? Duration(milliseconds: currentSegment.endMs)
          : null,
      loop: _loopSegment,
      artUri: _resolvedArtUri,
    ));
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    final handedOff = _handOffToBackground();
    if (_isBackground && !handedOff) {
      BgAudio.instance.ensureAudioHandler().then((h) async {
        try {
          await h.stop();
        } catch (_) {}
      });
    }

    // 전에는 `_isInitialized && _controller != null`일 때만 놓았다. 파일이
    // 깨졌거나 없어서 initialize()가 던지면, 또는 초기화가 끝나기 전에
    // 사용자가 뒤로 가면 _isInitialized가 false라 컨트롤러를 영영 안 놓았다.
    // 네이티브 플레이어가 그대로 남는다.
    _disposeController();

    disposeUiMixin();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Helpers (AudioModeMixin에서 사용)
  // ─────────────────────────────────────────────────────────────────

  @override
  Future<String> resolvedSourcePath() async {
    final src = _clip!.filePath;
    if (src.startsWith('/')) return src;
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/$src';
  }

  @override
  Future<Uri?> resolvedThumbUri() async {
    Uint8List? thumbBytes;
    try {
      final item =
          clipProvider.clipItems.firstWhere((it) => it.clip.id == clipId);
      thumbBytes = item.thumbnail;
    } catch (_) {
      thumbBytes = null;
    }

    if (thumbBytes == null || thumbBytes.isEmpty) return null;

    final tmpDir = await getTemporaryDirectory();
    final path = '${tmpDir.path}/clip_$clipId.jpg';
    final file = File(path);
    await file.writeAsBytes(thumbBytes, flush: true);

    return Uri.file(file.path);
  }
}
