// ============================================================================
// lib/features/player/presentation/mixins/audio_mode_mixin.dart
// ============================================================================
//
// [역할]
// 오디오 전용 모드(백그라운드 재생) 관련 상태와 메소드.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'package:parrokit/core/shared/utils/audio_bg.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/player/domain/player_state.dart';

/// 오디오 전용 모드 믹스인.
///
/// 백그라운드 오디오 재생 진입/탈출, 상태 관리.
mixin AudioModeMixin on ChangeNotifier {
  // ─────────────────────────────────────────────────────────────────
  // Abstract getters (메인 클래스에서 구현)
  // ─────────────────────────────────────────────────────────────────

  VideoPlayerController? get controller;
  Clip? get clip;
  Segment get currentSegment;
  bool get isBackground;
  PlayScope get scope;
  bool get loopSegment;
  double get playbackRate;

  // Setters
  set mutableIsBackground(bool value);
  set mutableBgPlaying(bool value);

  // Helper 메소드 (메인 클래스에서 구현)
  Future<String> resolvedSourcePath();
  Future<Uri?> resolvedThumbUri();

  // ─────────────────────────────────────────────────────────────────
  // Audio Only Mode
  // ─────────────────────────────────────────────────────────────────

  /// 오디오 전용 모드 토글.
  Future<void> toggleAudioOnlyMode() async {
    if (isBackground) {
      await exitAudioOnlyMode();
    } else {
      await enterAudioOnlyMode();
    }
  }

  /// 오디오 전용 모드 진입.
  ///
  /// [autoPlay]면 바로 이어서 튼다. 앱을 내렸을 때 끊기지 않게 하려는 것이라
  /// 사용자가 다시 재생을 누를 일이 없어야 한다(5차, 사용자 요청).
  Future<void> enterAudioOnlyMode({bool autoPlay = false}) async {
    if (isBackground ||
        controller?.value.isInitialized != true ||
        clip == null) {
      return;
    }

    mutableIsBackground = true;
    mutableBgPlaying = false;
    notifyListeners();

    try {
      await controller!.pause();
      final pos = controller!.value.position;

      final src = await resolvedSourcePath();
      if (src.isEmpty) return;

      final clipBegin = scope == PlayScope.segment
          ? Duration(milliseconds: currentSegment.startMs)
          : null;
      final clipEnd = scope == PlayScope.segment
          ? Duration(milliseconds: currentSegment.endMs)
          : null;

      final artUri = await resolvedThumbUri();

      final h = await BgAudio.instance.ensureAudioHandler();
      await (h as dynamic).loadSourceLocal(
        absolutePath: src,
        speed: playbackRate,
        clipBegin: clipBegin,
        clipEnd: clipEnd,
        loop: loopSegment,
        title: (clip?.title ?? '').isNotEmpty ? clip!.title : '클립',
        artUri: artUri,
      );
      await h.seek(pos);
      if (autoPlay) {
        await h.play();
        mutableBgPlaying = true;
      } else {
        await h.pause();
      }

      notifyListeners();
    } catch (_) {
      mutableIsBackground = false;
      mutableBgPlaying = false;
      notifyListeners();
    }
  }

  /// 오디오 전용 모드 탈출.
  Future<void> exitAudioOnlyMode() async {
    if (!isBackground) return;

    mutableIsBackground = false;
    notifyListeners();

    try {
      final h = await BgAudio.instance.ensureAudioHandler();
      Duration bgPos;
      try {
        bgPos = (h as dynamic).position as Duration? ?? Duration.zero;
      } catch (_) {
        bgPos = Duration.zero;
      }

      await h.stop();
      mutableBgPlaying = false;

      if (controller?.value.isInitialized == true) {
        var target = bgPos;
        if (scope == PlayScope.segment) {
          final st = Duration(milliseconds: currentSegment.startMs);
          final en = Duration(milliseconds: currentSegment.endMs);
          if (target < st || target >= en) {
            target = st;
          }
        }
        await controller!.seekTo(target);
        await controller!.setPlaybackSpeed(playbackRate);
      }
    } catch (_) {
      mutableIsBackground = true;
      mutableBgPlaying = true;
      notifyListeners();
    }
  }
}
