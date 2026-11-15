// ============================================================================
// lib/features/player/presentation/mixins/audio_mode_mixin.dart
// ============================================================================
//
// [역할]
// 오디오 전용 모드(백그라운드 재생) 관련 상태와 메소드.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:parrokit/core/shared/utils/audio_bg.dart';
import 'package:parrokit/features/collection/clip/player/presentation/engine/clip_player_engine.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/player/domain/player_state.dart';
import 'package:parrokit/features/collection/clip/player/domain/resume_target.dart';

/// 오디오 전용 모드 믹스인.
///
/// 백그라운드 오디오 재생 진입/탈출, 상태 관리.
mixin AudioModeMixin on ChangeNotifier {
  // ─────────────────────────────────────────────────────────────────
  // Abstract getters (메인 클래스에서 구현)
  // ─────────────────────────────────────────────────────────────────

  ClipPlayerEngine get engine;
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
        !engine.isReady ||
        clip == null) {
      return;
    }

    mutableIsBackground = true;
    mutableBgPlaying = false;
    notifyListeners();

    try {
      await engine.pause();
      final pos = engine.position;

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

      if (engine.isReady) {
        final target = resumeTargetAfterBackground(
          position: bgPos,
          segmentScope: scope == PlayScope.segment,
          segmentStart: Duration(milliseconds: currentSegment.startMs),
          segmentEnd: Duration(milliseconds: currentSegment.endMs),
          duration: engine.duration,
        );
        await engine.seekTo(target);
        await engine.setSpeed(playbackRate);
      }
    } catch (_) {
      mutableIsBackground = true;
      mutableBgPlaying = true;
      notifyListeners();
    }
  }
}
