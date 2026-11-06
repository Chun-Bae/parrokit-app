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

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/shared/utils/audio_bg.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/player/domain/player_state.dart';

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
    this.initialIndex = 0,
  }) {
    _init();
  }

  // ─────────────────────────────────────────────────────────────────
  // Dependencies
  // ─────────────────────────────────────────────────────────────────

  final int clipId;
  final ClipProvider clipProvider;
  final int initialIndex;

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

    loadClip();
  }

  /// 클립 데이터 로드.
  Future<void> loadClip() async {
    try {
      final payload = await clipProvider.fetchClipById(clipId);

      if (payload == null) {
        _errorMessage = '클립을 찾을 수 없습니다.';
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

      _isLoading = false;
      _isInitialized = true;
      _appBarTitle = (_clip?.title ?? '').isNotEmpty ? _clip!.title : '재생';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _clip = null;
      _segments = const [];
      notifyListeners();
    }
  }

  Future<void> _initVideo() async {
    if (_clip == null) return;

    final resolvedPath = await resolvedSourcePath();
    _controller = VideoPlayerController.file(File(resolvedPath));

    await _controller!.initialize();
    await _controller!.setLooping(false);
    await _controller!.setPlaybackSpeed(_playbackRate);

    if (_segments.isNotEmpty) {
      _segIndex = _segIndex.clamp(0, _segments.length - 1);
      await _controller!.seekTo(Duration(milliseconds: currentSegment.startMs));
    }

    _controller!.addListener(_onTick);
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
  Future<void> handleAppLifecycleChange(AppLifecycleState state) async {
    if (!_isInitialized || _clip == null || _segments.isEmpty) return;
    if (_isBackground) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_controller?.value.isInitialized == true &&
          _controller!.value.isPlaying) {
        await _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    if (_isBackground) {
      BgAudio.instance.ensureAudioHandler().then((h) async {
        try {
          await h.stop();
        } catch (_) {}
      });
    }

    if (_isInitialized && _controller != null) {
      _controller!.removeListener(_onTick);
      _controller!.dispose();
    }

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
