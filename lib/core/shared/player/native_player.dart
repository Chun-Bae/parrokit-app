// 영상과 소리를 한 플레이어로 다루는 네이티브 플레이어의 Flutter 쪽(5차).
//
// 지금까지는 화면용(video_player)과 백그라운드용(just_audio)이 따로라, 앱을
// 내릴 때마다 파일을 다시 읽고 자리를 맞춰 트느라 0.3초쯤 끊겼다. 하나의
// 플레이어가 계속 돌면 넘기는 과정 자체가 없어진다.
//
// 1단계(뼈대): 로컬 파일 읽기, 영상 보이기, play/pause/seek/속도.
// 백그라운드 유지와 잠금화면 조작은 2단계에서 붙인다. 지금은 iOS만 있다.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const String nativePlayerViewType = 'parrokit/native_player';

/// 네이티브 플레이어가 지금 이 기기에서 쓸 수 있는지.
bool get nativePlayerSupported => !kIsWeb && Platform.isIOS;

/// 플레이어가 알려 주는 지금 상태.
@immutable
class NativePlayerState {
  const NativePlayerState({
    this.ready = false,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.errorMessage,
  });

  final bool ready;
  final bool playing;
  final Duration position;
  final Duration duration;
  final double speed;

  /// 영상을 열지 못했을 때만 값이 있다.
  final String? errorMessage;

  NativePlayerState copyWith({
    bool? ready,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    String? errorMessage,
    bool clearError = false,
  }) =>
      NativePlayerState(
        ready: ready ?? this.ready,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

/// 네이티브 플레이어 하나를 다룬다. 화면([NativePlayerSurface])이 만들어지면
/// [attach]가 불려 채널이 이어진다.
class NativePlayerController extends ChangeNotifier {
  NativePlayerController({
    @visibleForTesting MethodChannel Function(int id)? channelOf,
    @visibleForTesting Stream<dynamic> Function(int id)? eventsOf,
  })  : _channelOf = channelOf ?? _defaultChannel,
        _eventsOf = eventsOf ?? _defaultEvents;

  final MethodChannel Function(int id) _channelOf;
  final Stream<dynamic> Function(int id) _eventsOf;

  static MethodChannel _defaultChannel(int id) =>
      MethodChannel('$nativePlayerViewType/$id');

  static Stream<dynamic> _defaultEvents(int id) =>
      EventChannel('$nativePlayerViewType/$id/events').receiveBroadcastStream();

  MethodChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _disposed = false;

  NativePlayerState _state = const NativePlayerState();
  NativePlayerState get state => _state;

  /// 화면이 아직 안 만들어졌으면 false. 이때 부른 명령은 그냥 넘어간다.
  bool get isAttached => _channel != null;

  /// 플랫폼 뷰가 만들어졌을 때 불린다.
  void attach(int viewId) {
    if (_disposed) return;
    _channel = _channelOf(viewId);
    _sub?.cancel();
    _sub = _eventsOf(viewId).listen(_onEvent, onError: (Object error) {
      _set(_state.copyWith(errorMessage: '$error'));
    });
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final map = raw.cast<Object?, Object?>();
    switch (map['event']) {
      case 'state':
        _set(NativePlayerState(
          ready: map['ready'] == true,
          playing: map['playing'] == true,
          position: _ms(map['positionMs']),
          duration: _ms(map['durationMs']),
          speed: (map['speed'] as num?)?.toDouble() ?? _state.speed,
        ));
      case 'error':
        _set(_state.copyWith(
          playing: false,
          errorMessage: map['message'] as String? ?? '영상을 열지 못했어요.',
        ));
    }
  }

  static Duration _ms(Object? value) =>
      Duration(milliseconds: (value as num?)?.toInt() ?? 0);

  Future<void> load(String absolutePath, {double speed = 1.0}) async {
    _set(_state.copyWith(clearError: true, ready: false));
    await _invoke('load', {'path': absolutePath, 'speed': speed});
  }

  Future<void> play() => _invoke('play');

  Future<void> pause() => _invoke('pause');

  Future<void> seek(Duration position) =>
      _invoke('seek', {'positionMs': position.inMilliseconds});

  Future<void> setSpeed(double speed) async {
    _set(_state.copyWith(speed: speed));
    await _invoke('setSpeed', {'speed': speed});
  }

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>(method, args);
    } on PlatformException catch (error) {
      _set(_state.copyWith(errorMessage: error.message ?? '플레이어 오류'));
    } on MissingPluginException {
      // 이 기기에는 네이티브 플레이어가 없다. 조용히 넘어간다.
    }
  }

  void _set(NativePlayerState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    unawaited(_invoke('dispose'));
    _channel = null;
    super.dispose();
  }
}

/// 영상이 그려지는 자리.
class NativePlayerSurface extends StatelessWidget {
  const NativePlayerSurface({super.key, required this.controller});

  final NativePlayerController controller;

  @override
  Widget build(BuildContext context) {
    if (!nativePlayerSupported) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    return UiKitView(
      viewType: nativePlayerViewType,
      onPlatformViewCreated: controller.attach,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
