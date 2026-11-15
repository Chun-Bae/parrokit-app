// 새 플레이어를 화면 밖에서 들고 있는 곳(5차 4단계).
//
// 플레이어가 화면과 함께 죽으면, 나갈 때마다 소리 전용 플레이어로 넘겨야
// 하고 그 사이가 끊긴다. 플레이어를 앱이 들고 있으면 화면을 나가도 같은
// 플레이어가 그대로 돈다. 다시 들어오면 멈추지 않고 그 자리에서 영상이
// 다시 보인다.

import 'package:flutter/foundation.dart';

import 'package:parrokit/features/collection/clip/player/presentation/engine/native_clip_player_engine.dart';

class ClipPlaybackHolder extends ChangeNotifier {
  ClipPlaybackHolder({NativeClipPlayerEngine Function()? engineOf})
      : _engineOf = engineOf ?? NativeClipPlayerEngine.new;

  final NativeClipPlayerEngine Function() _engineOf;

  NativeClipPlayerEngine? _engine;
  int? _clipId;
  String _title = '';
  bool _disposed = false;

  /// 지금 들고 있는 클립. 없으면 null.
  int? get clipId => _clipId;

  /// 줄에 보일 이름. 플레이어가 읽어 둔 이름을 먼저 쓴다.
  String get title {
    final fromEngine = _engine?.title ?? '';
    return fromEngine.isNotEmpty ? fromEngine : _title;
  }

  /// 아래에 '듣는 중' 줄을 띄울 만큼 재생이 살아 있는지.
  bool get isActive => _engine != null && _clipId != null;

  bool get isPlaying => _engine?.isPlaying ?? false;

  NativeClipPlayerEngine? get engine => _engine;

  /// [clipId]를 틀 플레이어를 준다. 이미 그 클립을 들고 있으면 그대로 쓴다.
  ///
  /// 돌려주는 값의 `loaded`가 참이면 영상을 다시 읽을 필요가 없다는 뜻이다.
  ({NativeClipPlayerEngine engine, bool loaded}) engineFor({
    required int clipId,
    required String title,
  }) {
    final same = _clipId == clipId && _engine != null;
    if (same) {
      _title = title;
      return (engine: _engine!, loaded: _engine!.isReady);
    }
    // 다른 클립이면 쓰던 것은 놓는다. 둘이 같이 울리지 않게.
    _engine?.dispose();
    final engine = _engineOf();
    _engine = engine;
    _clipId = clipId;
    _title = title;
    engine.addListener(_onEngineChanged);
    _notify();
    return (engine: engine, loaded: false);
  }

  void _onEngineChanged() => _notify();

  Future<void> pause() async => _engine?.pause();

  Future<void> resume() async => _engine?.play();

  /// 재생을 멈추고 플레이어를 놓는다('듣는 중' 줄의 닫기).
  Future<void> stop() async {
    final engine = _engine;
    _engine = null;
    _clipId = null;
    _title = '';
    if (engine != null) {
      engine.removeListener(_onEngineChanged);
      await engine.dispose();
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _engine?.removeListener(_onEngineChanged);
    _engine?.dispose();
    _engine = null;
    super.dispose();
  }
}
