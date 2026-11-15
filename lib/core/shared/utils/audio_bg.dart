// audio_bg.dart
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// 백그라운드 오디오를 위한 싱글톤 래퍼
class BgAudio {
  BgAudio._();
  static final BgAudio instance = BgAudio._();

  AudioHandler? _handler;
  Future<AudioHandler>? _booting;

  /// 항상 같은 AudioHandler 인스턴스를 돌려주는 보장된 엔트리 포인트
  Future<AudioHandler> ensureAudioHandler() {
    // 이미 완성된 instance 있으면 즉시 반환
    if (_handler != null) return Future.value(_handler);

    // init 중이면 그 Future 반환 (race 방지)
    if (_booting != null) return _booting!;

    // 처음 딱 한 번만 init
    return _booting = _init();
  }

  Future<AudioHandler> _init() async {
    try {
      final handler = await AudioService.init(
        builder: () => _BgAudioHandler.instance,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'parrokit.audio',
          androidNotificationChannelName: 'Parrokit Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      _handler = handler;
      return handler;
    } catch (_) {
      // 실패한 Future를 _booting에 그대로 들고 있으면, 그 뒤의 모든 호출이
      // 같은 실패를 돌려받는다. 한 번 넘어지면 앱이 꺼질 때까지 백그라운드
      // 오디오가 영영 안 살아난다. 비워 두고 다음에 다시 해 보게 한다.
      _booting = null;
      rethrow;
    }
  }
}

class _BgAudioHandler extends BaseAudioHandler with SeekHandler {
  // 싱글톤 인스턴스
  static final _BgAudioHandler instance = _BgAudioHandler._internal();

  final _player = AudioPlayer();

  // 로컬만 쓸 거라 파일 경로(절대경로)만 기억
  String? _currentPath;
  Duration? _clipStart;
  Duration? _clipEnd;

  _BgAudioHandler._internal() {
    _player.playbackEventStream.listen((e) {
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            _player.playing ? MediaControl.pause : MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          processingState: switch (_player.processingState) {
            ProcessingState.idle => AudioProcessingState.idle,
            ProcessingState.loading => AudioProcessingState.loading,
            ProcessingState.buffering => AudioProcessingState.buffering,
            ProcessingState.ready => AudioProcessingState.ready,
            ProcessingState.completed => AudioProcessingState.completed,
          },
          playing: _player.playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
        ),
      );
    });
  }

  AudioSource _buildSource() {
    final base = AudioSource.uri(Uri.file(_currentPath!));
    if (_clipStart != null || _clipEnd != null) {
      return ClippingAudioSource(
        start: _clipStart,
        end: _clipEnd,
        child: base,
      );
    }
    return base;
  }

  /// 소리를 실제로 읽어 올리는 곳. 읽는 데 시간이 걸린다.
  Future<void> _applySource({
    required String absolutePath,
    required double speed,
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
  }) async {
    _currentPath = absolutePath;
    _clipStart = clipBegin;
    _clipEnd = clipEnd;
    await _player.setAudioSource(_buildSource(), preload: true);
    await _player.setSpeed(speed);
    await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
  }

  /// 소리 없이 미리 읽어만 둔다(5차, 사용자 신고).
  ///
  /// 플레이어를 나가는 순간에야 읽기 시작하면 소리가 이어지기까지 한 템포
  /// 쉰다. 화면을 보고 있는 동안 미리 읽어 두면 나갈 때는 틀기만 하면 된다.
  /// 알림(지금 듣는 것)은 아직 띄우지 않는다. 틀지도 않았는데 잠금 화면에
  /// 뜨면 안 된다.
  Future<void> prepareSourceLocal({
    required String absolutePath,
    double speed = 1.0,
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
  }) async {
    assert(absolutePath.startsWith('/'), 'absolute path required');
    await _applySource(
      absolutePath: absolutePath,
      speed: speed,
      clipBegin: clipBegin,
      clipEnd: clipEnd,
      loop: loop,
    );
  }

  // 로컬 전용 로더
  Future<void> loadSourceLocal({
    required String absolutePath,
    double speed = 1.0,
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
    String? title,
    String? subtitle,
    Uri? artUri,
    bool sourceReady = false,
  }) async {
    // 안전장치: 반드시 절대경로
    assert(absolutePath.startsWith('/'), 'absolute path required');

    final item = MediaItem(
      id: absolutePath,
      title: title ?? '클립',
      artist: subtitle,
      artUri: artUri,
      duration:
          clipBegin != null && clipEnd != null ? clipEnd - clipBegin : null,
    );
    mediaItem.add(item);

    // 미리 읽어 둔 그대로면 다시 읽지 않는다.
    if (sourceReady) return;
    await _applySource(
      absolutePath: absolutePath,
      speed: speed,
      clipBegin: clipBegin,
      clipEnd: clipEnd,
      loop: loop,
    );
  }

  // 클립 변경 시 소스 재구성(재생상태/포지션 유지)
  Future<void> setClip({Duration? start, Duration? end}) async {
    if (_currentPath == null) return;
    _clipStart = start;
    _clipEnd = end;

    final wasPlaying = _player.playing;
    final pos = _player.position;

    final src = _buildSource();
    await _player.setAudioSource(src, initialPosition: pos, preload: true);
    if (wasPlaying) await _player.play();
  }

  Future<void> setLoop(bool on) =>
      _player.setLoopMode(on ? LoopMode.one : LoopMode.off);

  @override
  Future<void> setSpeed(double s) => _player.setSpeed(s);

  // just_audio의 play()가 주는 Future는 '재생이 끝날 때'까지 끝나지 않는다.
  // 그래서 await 하면 그 뒤 코드가 영영 안 돌았다. 플레이어를 나가서 소리를
  // 넘길 때, 소리는 났지만 '듣는 중' 줄을 띄우는 코드까지 못 가서 첫 진입에는
  // 줄이 안 뜨고, 다음에 들어가 멈출 때에야 뒤늦게 떴다(5차, 사용자 신고).
  // 시작만 시키고 끝은 기다리지 않는다.
  @override
  Future<void> play() async {
    unawaited(_player.play().catchError((_) {}));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Duration get position => _player.position;

  bool get playing => _player.playing;
}
