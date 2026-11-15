// 영상과 소리를 한 플레이어로 다루는 네이티브 플레이어의 Flutter 쪽(5차).
//
// 지금까지는 화면용(video_player)과 백그라운드용(just_audio)이 따로라, 앱을
// 내릴 때마다 파일을 다시 읽고 자리를 맞춰 트느라 0.3초쯤 끊겼다. 하나의
// 플레이어가 계속 돌면 넘기는 과정 자체가 없어진다.
//
// 그림은 Flutter 텍스처로 받는다. AVPlayerLayer를 플랫폼 뷰에 얹는 쪽은
// 시뮬레이터에서 까맣게 나왔다(반복 262).
//
// 1단계(뼈대): 로컬 파일 읽기, 영상 보이기, play/pause/seek/속도.
// 백그라운드 유지와 잠금화면 조작은 2단계에서 붙인다. 지금은 iOS만 있다.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const String nativePlayerChannelName = 'parrokit/native_player';

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
    this.width = 0,
    this.height = 0,
    this.frames = 0,
    this.pulls = 0,
    this.clipBegin = Duration.zero,
    this.clipEnd = Duration.zero,
    this.loop = false,
    this.errorMessage,
  });

  final bool ready;
  final bool playing;
  final Duration position;
  final Duration duration;
  final double speed;

  /// 영상 크기. 아직 모르면 0.
  final int width;
  final int height;

  /// 진단용: 네이티브가 받은 프레임 수와 Flutter가 가져간 횟수.
  final int frames;
  final int pulls;

  /// 틀고 있는 구간. 둘 다 0이면 영상 전체.
  final Duration clipBegin;
  final Duration clipEnd;
  final bool loop;

  bool get hasClipRange => clipEnd > clipBegin;

  /// 가로세로 비. 모르면 16:9로 본다.
  double get aspectRatio =>
      (width > 0 && height > 0) ? width / height : 16 / 9;

  /// 영상을 열지 못했을 때만 값이 있다.
  final String? errorMessage;

  NativePlayerState copyWith({
    bool? ready,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    int? width,
    int? height,
    int? frames,
    int? pulls,
    Duration? clipBegin,
    Duration? clipEnd,
    bool? loop,
    String? errorMessage,
    bool clearError = false,
  }) =>
      NativePlayerState(
        ready: ready ?? this.ready,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        width: width ?? this.width,
        height: height ?? this.height,
        frames: frames ?? this.frames,
        pulls: pulls ?? this.pulls,
        clipBegin: clipBegin ?? this.clipBegin,
        clipEnd: clipEnd ?? this.clipEnd,
        loop: loop ?? this.loop,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

/// 네이티브 플레이어 하나를 다룬다. [create]로 텍스처를 하나 받아 쓴다.
class NativePlayerController extends ChangeNotifier {
  NativePlayerController({
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting Stream<dynamic> Function(int textureId)? eventsOf,
  })  : _channel = channel ?? const MethodChannel(nativePlayerChannelName),
        _eventsOf = eventsOf ?? _defaultEvents;

  final MethodChannel _channel;
  final Stream<dynamic> Function(int textureId) _eventsOf;

  static Stream<dynamic> _defaultEvents(int textureId) =>
      EventChannel('$nativePlayerChannelName/$textureId/events')
          .receiveBroadcastStream();

  StreamSubscription<dynamic>? _sub;
  bool _disposed = false;

  int? _textureId;

  /// 그림을 받을 텍스처. 아직 안 만들었으면 null.
  int? get textureId => _textureId;

  NativePlayerState _state = const NativePlayerState();
  NativePlayerState get state => _state;

  /// 아직 플레이어를 안 만들었으면 false. 이때 부른 명령은 그냥 넘어간다.
  bool get isReady => _textureId != null;

  /// 네이티브에 플레이어를 하나 만든다. 화면을 열 때 한 번 부른다.
  Future<void> create() async {
    if (_disposed || _textureId != null) return;
    try {
      final made = await _channel
          .invokeMapMethod<String, dynamic>('create');
      final id = (made?['textureId'] as num?)?.toInt();
      if (id == null || _disposed) return;
      _textureId = id;
      _sub = _eventsOf(id).listen(_onEvent, onError: (Object error) {
        _set(_state.copyWith(errorMessage: '$error'));
      });
      _set(_state);
    } on PlatformException catch (error) {
      _set(_state.copyWith(errorMessage: error.message ?? '플레이어 오류'));
    } on MissingPluginException {
      // 이 기기에는 네이티브 플레이어가 없다. 조용히 넘어간다.
    }
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
          width: (map['width'] as num?)?.toInt() ?? _state.width,
          height: (map['height'] as num?)?.toInt() ?? _state.height,
          frames: (map['frames'] as num?)?.toInt() ?? _state.frames,
          pulls: (map['pulls'] as num?)?.toInt() ?? _state.pulls,
          clipBegin: _ms(map['clipBeginMs']),
          clipEnd: _ms(map['clipEndMs']),
          loop: map['loop'] == true,
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

  /// [title]은 잠금화면·제어센터에 보일 이름이다.
  /// [clipBegin]~[clipEnd]를 주면 그 구간만 튼다. [loop]면 끝에서 되돌아간다.
  Future<void> load(
    String absolutePath, {
    double speed = 1.0,
    String title = '',
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
  }) async {
    _set(_state.copyWith(clearError: true, ready: false));
    await _invoke('load', {
      'path': absolutePath,
      'speed': speed,
      'title': title,
      ..._rangeArgs(clipBegin, clipEnd, loop),
    });
  }

  /// 틀 구간과 반복을 바꾼다. 구간을 비우면 영상 전체.
  Future<void> setRange({
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
  }) =>
      _invoke('setRange', _rangeArgs(clipBegin, clipEnd, loop));

  static Map<String, Object?> _rangeArgs(
          Duration? begin, Duration? end, bool loop) =>
      {
        'clipBeginMs': begin?.inMilliseconds,
        'clipEndMs': end?.inMilliseconds,
        'loop': loop,
      };

  Future<void> play() => _invoke('play');

  Future<void> pause() => _invoke('pause');

  Future<void> seek(Duration position) =>
      _invoke('seek', {'positionMs': position.inMilliseconds});

  Future<void> setSpeed(double speed) async {
    _set(_state.copyWith(speed: speed));
    await _invoke('setSpeed', {'speed': speed});
  }

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    final id = _textureId;
    if (id == null) return;
    try {
      await _channel.invokeMethod<void>(method, {'textureId': id, ...?args});
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
    if (_disposed) return; // 두 번 닫아도 탈 나지 않게
    final id = _textureId;
    _disposed = true;
    _sub?.cancel();
    if (id != null) {
      unawaited(_channel
          .invokeMethod<void>('dispose', {'textureId': id})
          .catchError((_) {}));
    }
    _textureId = null;
    super.dispose();
  }
}

/// 영상이 그려지는 자리.
class NativePlayerSurface extends StatelessWidget {
  const NativePlayerSurface({super.key, required this.controller});

  final NativePlayerController controller;

  @override
  Widget build(BuildContext context) {
    final id = controller.textureId;
    if (!nativePlayerSupported || id == null) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.state.aspectRatio,
          child: Texture(textureId: id),
        ),
      ),
    );
  }
}
