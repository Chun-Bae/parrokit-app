// 플레이어 화면이 영상을 다루는 창구(5차 4단계).
//
// 지금은 video_player가 영상을, audio_service가 백그라운드 소리를 맡는다.
// 네이티브 플레이어로 갈아끼우려면 화면이 둘 중 무엇을 쓰는지 몰라야 한다.
// 화면과 ViewModel은 이 창구만 알고, 실제 플레이어는 아래 구현이 맡는다.

import 'dart:io' show File;

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

abstract class ClipPlayerEngine implements Listenable {
  /// 영상을 읽어 틀 준비가 됐는지.
  bool get isReady;

  bool get isPlaying;

  Duration get position;

  Duration get duration;

  /// 가로세로 비. 모르면 0.
  double get aspectRatio;

  /// 영상 크기. 모르면 Size.zero.
  Size get size;

  /// 파일을 읽는다. 끝나면 [isReady]가 참이 된다.
  Future<void> open(String absolutePath, {double speed = 1.0});

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setSpeed(double speed);

  /// 영상 전체를 끝에서 처음으로 되돌릴지.
  Future<void> setLooping(bool value);

  /// 지금 영상을 놓는다. 창구는 그대로라 다시 [open]할 수 있다.
  Future<void> close();

  /// 영상이 그려질 자리.
  Widget surface();

  Future<void> dispose();
}

/// 지금까지 쓰던 video_player로 돌아가는 구현.
class VideoPlayerEngine extends ChangeNotifier implements ClipPlayerEngine {
  VideoPlayerController? _controller;

  /// 테스트와 화면에서 쓸 수 있게 열어 둔다. 새 플레이어로 다 옮기면 없앤다.
  VideoPlayerController? get controller => _controller;

  @override
  bool get isReady => _controller?.value.isInitialized == true;

  @override
  bool get isPlaying => isReady && _controller!.value.isPlaying;

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  @override
  double get aspectRatio => _controller?.value.aspectRatio ?? 0;

  @override
  Size get size => _controller?.value.size ?? Size.zero;

  @override
  Future<void> open(String absolutePath, {double speed = 1.0}) async {
    await close();
    final controller = VideoPlayerController.file(File(absolutePath));
    _controller = controller;
    await controller.initialize();
    // 기다리는 사이 화면이 닫혔거나 다른 영상을 열었으면 그만둔다.
    if (!identical(_controller, controller)) {
      await controller.dispose();
      return;
    }
    await controller.setLooping(false);
    await controller.setPlaybackSpeed(speed);
    controller.addListener(notifyListeners);
    notifyListeners();
  }

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> seekTo(Duration position) async =>
      _controller?.seekTo(position);

  @override
  Future<void> setSpeed(double speed) async =>
      _controller?.setPlaybackSpeed(speed);

  @override
  Future<void> setLooping(bool value) async => _controller?.setLooping(value);

  @override
  Future<void> close() async {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    controller.removeListener(notifyListeners);
    await controller.dispose();
  }

  @override
  Widget surface() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return VideoPlayer(controller);
  }

  @override
  Future<void> dispose() async {
    await close();
    super.dispose();
  }
}
