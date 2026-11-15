// 클립 플레이어를 네이티브 플레이어로 돌리는 구현(5차 4단계).
//
// video_player는 앱을 내리면 멈춰서, 소리 전용 플레이어로 넘겨야 했다.
// 그 사이가 0.3초쯤 끊긴다(사용자 신고). 이 창구는 우리가 만든 AVPlayer
// 하나를 쓰므로, 화면을 나가도 앱을 내려도 같은 플레이어가 그대로 돈다.

import 'package:flutter/widgets.dart';

import 'package:parrokit/core/shared/player/native_player.dart';
import 'clip_player_engine.dart';

class NativeClipPlayerEngine extends ChangeNotifier
    implements ClipPlayerEngine {
  NativeClipPlayerEngine({NativePlayerController? player})
      : _player = player ?? NativePlayerController() {
    _player.addListener(notifyListeners);
  }

  final NativePlayerController _player;

  NativePlayerState get _state => _player.state;

  /// 같은 플레이어가 그대로 돈다. 넘길 것이 없다.
  @override
  bool get keepsPlayingInBackground => true;

  /// 구간 끝을 플레이어가 정확히 잡는다(5차 3단계).
  @override
  bool get handlesClipRange => true;

  @override
  bool get isReady => _state.ready;

  @override
  bool get isPlaying => _state.playing;

  @override
  Duration get position => _state.position;

  @override
  Duration get duration => _state.duration;

  /// video_player와 같은 뜻으로, 아직 모르면 0을 준다.
  @override
  double get aspectRatio =>
      (_state.width > 0 && _state.height > 0) ? _state.aspectRatio : 0;

  @override
  Size get size => _state.width > 0
      ? Size(_state.width.toDouble(), _state.height.toDouble())
      : Size.zero;

  @override
  String get title => _title;
  String _title = '';

  @override
  Future<void> open(String absolutePath,
      {double speed = 1.0, String title = ''}) async {
    _title = title;
    await _player.create();
    await _player.load(absolutePath, speed: speed, title: title);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  /// 영상 전체를 끝에서 처음으로 되돌릴지. 구간은 [setRange]가 따로 정한다.
  @override
  Future<void> setLooping(bool value) => _player.setRange(loop: value);

  @override
  Future<void> setRange({
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
  }) =>
      _player.setRange(
          clipBegin: clipBegin, clipEnd: clipEnd, loop: loop);

  @override
  Future<void> close() async {
    await _player.pause();
  }

  @override
  Widget surface() => NativePlayerSurface(controller: _player);

  @override
  Future<void> dispose() async {
    _player.removeListener(notifyListeners);
    _player.dispose();
    super.dispose();
  }
}
