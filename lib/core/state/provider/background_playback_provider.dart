// 플레이어 화면을 나가도 소리가 이어지게 들고 있는 곳(5차, 사용자 요청).
//
// 전에는 화면이 재생을 들고 있어서, 뒤로 나가면 그대로 멈췄다. 다른 앱들은
// 목록을 뒤지는 동안에도 계속 들린다. 재생을 화면이 아니라 앱이 들게 한다.
//
// 영상은 화면이 있어야 보이므로 소리만 이어 간다. 돌아오면 그 자리부터
// 다시 영상으로 본다.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/audio_bg.dart';

/// 지금 이어 듣고 있는 클립.
class BackgroundPlayback {
  const BackgroundPlayback({
    required this.clipId,
    required this.title,
    required this.playing,
  });

  final int clipId;
  final String title;
  final bool playing;

  BackgroundPlayback copyWith({bool? playing}) => BackgroundPlayback(
        clipId: clipId,
        title: title,
        playing: playing ?? this.playing,
      );
}

class BackgroundPlaybackProvider extends ChangeNotifier {
  BackgroundPlaybackProvider({Future<AudioHandler> Function()? handler})
      : _handlerOf = handler ?? BgAudio.instance.ensureAudioHandler;

  final Future<AudioHandler> Function() _handlerOf;

  BackgroundPlayback? _current;
  StreamSubscription<PlaybackState>? _stateSub;
  bool _disposed = false;

  /// 지금 이어 듣는 중이면 그 클립. 아니면 null.
  BackgroundPlayback? get current => _current;

  bool get isActive => _current != null;

  /// 소리 쪽을 미리 깨워 둔다.
  ///
  /// 첫 진입에서는 AudioService가 아직 안 올라와 있다. 나가는 순간에야
  /// 띄우면 소리가 이어지기까지 눈에 띄게 늦다. 플레이어가 열릴 때 미리
  /// 불러 둔다(5차).
  Future<void> warmUp() async {
    try {
      await _handlerOf();
    } catch (error) {
      AppLogger.w('[BackgroundPlayback] 소리를 미리 깨우지 못했어요: $error');
    }
  }

  /// 플레이어를 나갈 때 재생을 넘겨받는다. 받은 자리부터 소리로 이어 튼다.
  Future<void> takeOver({
    required int clipId,
    required String title,
    required String absolutePath,
    required Duration position,
    required double speed,
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
    Uri? artUri,
  }) async {
    if (absolutePath.isEmpty) return;
    try {
      // 처음 한 번은 소리 쪽이 늦게 올라와 실패할 수 있다. 한 번 더 해 본다.
      AudioHandler handler;
      try {
        handler = await _handlerOf();
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        handler = await _handlerOf();
      }
      await (handler as dynamic).loadSourceLocal(
        absolutePath: absolutePath,
        speed: speed,
        clipBegin: clipBegin,
        clipEnd: clipEnd,
        loop: loop,
        title: title.isEmpty ? '클립' : title,
        artUri: artUri,
      );
      await handler.seek(position);
      // play()는 기다리지 않는다. 소리 쪽 구현에 따라 '재생이 끝날 때'까지
      // 끝나지 않는 Future를 주어, 기다리면 아래 줄이 영영 안 돌았다
      // (첫 진입에서 '듣는 중' 줄이 안 떴다. 5차, 사용자 신고).
      unawaited(handler.play());
      _listenTo(handler);
      _set(BackgroundPlayback(
        clipId: clipId,
        title: title.isEmpty ? '클립' : title,
        playing: true,
      ));
    } catch (error) {
      AppLogger.w('[BackgroundPlayback] 이어 듣기를 시작하지 못했어요: $error');
      _set(null);
    }
  }

  /// 플레이어로 돌아갈 때. 소리를 멈추고 어디까지 들었는지 돌려준다.
  Future<Duration> handBack() async {
    final handler = await _safeHandler();
    var position = Duration.zero;
    if (handler != null) {
      try {
        position = (handler as dynamic).position as Duration? ?? Duration.zero;
      } catch (_) {/* 위치를 모르면 처음부터 */}
      try {
        await handler.stop();
      } catch (_) {/* 이미 멈춘 것은 넘어간다 */}
    }
    _set(null);
    return position;
  }

  Future<void> pause() async {
    final handler = await _safeHandler();
    if (handler == null) return;
    await handler.pause();
    if (_current != null) _set(_current!.copyWith(playing: false));
  }

  Future<void> resume() async {
    final handler = await _safeHandler();
    if (handler == null) return;
    unawaited(handler.play());
    if (_current != null) _set(_current!.copyWith(playing: true));
  }

  /// 아래 줄의 '닫기'. 소리를 멈추고 줄을 치운다.
  Future<void> stop() async {
    await handBack();
  }

  Future<AudioHandler?> _safeHandler() async {
    try {
      return await _handlerOf();
    } catch (error) {
      AppLogger.w('[BackgroundPlayback] 소리를 다루지 못했어요: $error');
      return null;
    }
  }

  void _listenTo(AudioHandler handler) {
    _stateSub?.cancel();
    _stateSub = handler.playbackState.listen((state) {
      final now = _current;
      if (now == null) return;
      // 끝까지 들었으면 줄을 치운다. 전에는 '이어 듣기'만 뜬 채로 남아,
      // 눌러도 아무 소리가 안 나는 줄이 화면 아래에 붙어 있었다(5차).
      if (state.processingState == AudioProcessingState.completed) {
        unawaited(stop());
        return;
      }
      if (now.playing != state.playing) {
        _set(now.copyWith(playing: state.playing));
      }
    });
  }

  void _set(BackgroundPlayback? next) {
    _current = next;
    if (next == null) {
      _stateSub?.cancel();
      _stateSub = null;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    super.dispose();
  }
}
