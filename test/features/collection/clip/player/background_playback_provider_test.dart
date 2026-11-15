// 플레이어를 나가도 이어 듣기(5차, 사용자 요청).

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/audio_focus.dart';
import 'package:parrokit/core/state/provider/background_playback_provider.dart';

/// 실제 소리를 내지 않고 부른 것만 적어 두는 가짜 핸들러.
class _FakeHandler extends BaseAudioHandler {
  final calls = <String>[];
  Duration position = const Duration(seconds: 7);
  bool loadFails = false;

  /// 읽기를 일부러 늦추고 싶을 때.
  Completer<void>? loadGate;

  Future<void> prepareSourceLocal({
    required String absolutePath,
    double speed = 1.0,
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
  }) async {
    if (loadFails) throw StateError('못 읽음');
    calls.add('prepare:$absolutePath speed=$speed loop=$loop');
  }

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
    if (loadFails) throw StateError('못 읽음');
    if (loadGate != null) await loadGate!.future;
    calls.add('load:$absolutePath speed=$speed loop=$loop title=$title '
        'ready=$sourceReady');
  }

  /// just_audio처럼 '재생이 끝날 때'까지 안 끝나는 Future를 주는 흉내.
  bool playNeverReturns = false;
  final _playForever = Completer<void>();

  @override
  Future<void> play() {
    calls.add('play');
    playbackState.add(PlaybackState(playing: true));
    if (playNeverReturns) return _playForever.future;
    return Future<void>.value();
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playbackState.add(PlaybackState(playing: false));
  }

  @override
  Future<void> seek(Duration p) async => calls.add('seek:${p.inSeconds}');

  @override
  Future<void> stop() async {
    calls.add('stop');
    playbackState.add(PlaybackState(
        playing: false, processingState: AudioProcessingState.idle));
  }

  /// 끝까지 들었을 때 플레이어가 알리는 것과 같은 상태.
  void finish() => playbackState.add(PlaybackState(
      playing: false, processingState: AudioProcessingState.completed));
}

void main() {
  late _FakeHandler handler;
  late BackgroundPlaybackProvider provider;
  late int handlerCalls;

  setUp(() {
    handler = _FakeHandler();
    handlerCalls = 0;
    provider = BackgroundPlaybackProvider(handler: () async {
      handlerCalls++;
      return handler;
    });
  });

  tearDown(() => provider.dispose());

  Future<void> takeOver({int clipId = 1, String title = '카페에서'}) =>
      provider.takeOver(
        clipId: clipId,
        title: title,
        absolutePath: '/tmp/a.mp4',
        position: const Duration(seconds: 3),
        speed: 1.5,
        loop: true,
      );

  test('나갈 때 넘기면 그 자리부터 이어서 튼다', () async {
    await takeOver();

    expect(handler.calls, contains('seek:3'));
    expect(handler.calls, contains('play'));
    expect(handler.calls.first, contains('speed=1.5'));
    expect(handler.calls.first, contains('loop=true'));
    expect(provider.isActive, isTrue);
    expect(provider.current!.title, '카페에서');
    expect(provider.current!.playing, isTrue);
  });

  test('멈추고 다시 이어 들을 수 있다', () async {
    await takeOver();

    await provider.pause();
    expect(provider.current!.playing, isFalse);

    await provider.resume();
    expect(provider.current!.playing, isTrue);
  });

  test('돌아가면 소리를 멈추고 들은 자리를 돌려준다', () async {
    await takeOver();

    final at = await provider.handBack();

    expect(at, const Duration(seconds: 7));
    expect(handler.calls, contains('stop'));
    expect(provider.isActive, isFalse, reason: '줄도 사라진다');
  });

  test('닫으면 멈추고 줄이 사라진다', () async {
    await takeOver();

    await provider.stop();

    expect(handler.calls, contains('stop'));
    expect(provider.isActive, isFalse);
  });

  test('소리를 못 틀면 줄을 띄우지 않는다', () async {
    handler.loadFails = true;

    await takeOver();

    expect(provider.isActive, isFalse);
  });

  test('경로가 없으면 아무 일도 하지 않는다', () async {
    await provider.takeOver(
      clipId: 1,
      title: '제목',
      absolutePath: '',
      position: Duration.zero,
      speed: 1,
    );

    expect(handler.calls, isEmpty);
    expect(provider.isActive, isFalse);
  });

  test('끝까지 들으면 줄이 알아서 사라진다', () async {
    await takeOver();

    handler.finish();
    // 상태 알림이 한 바퀴 돌 때까지 기다린다.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.isActive, isFalse,
        reason: '눌러도 소리가 안 나는 줄이 남으면 안 된다');
    expect(handler.calls, contains('stop'));
  });

  test('재생 시작을 기다리느라 줄이 늦게 뜨지 않는다', () async {
    // just_audio의 play()는 재생이 끝나야 Future가 끝난다. 그것을 기다렸더니
    // 소리는 나는데 줄을 띄우는 코드까지 못 가서, 첫 진입에는 줄이 안 뜨고
    // 다음에 들어가 멈출 때에야 뒤늦게 떴다(5차, 사용자 신고).
    handler.playNeverReturns = true;

    await takeOver().timeout(const Duration(seconds: 2));

    expect(handler.calls, contains('play'));
    expect(provider.isActive, isTrue, reason: '첫 진입에서 바로 줄이 떠야 한다');
  });

  test('플레이어가 열릴 때 소리를 미리 읽어 둔다', () async {
    await provider.prepare(
        absolutePath: '/tmp/a.mp4', speed: 1.5, loop: true);

    expect(handlerCalls, 1);
    expect(handler.calls, ['prepare:/tmp/a.mp4 speed=1.5 loop=true']);
    expect(provider.isActive, isFalse, reason: '읽어만 두고 틀지는 않는다');
  });

  test('미리 읽어 둔 그대로 나가면 다시 읽지 않는다', () async {
    await provider.prepare(
        absolutePath: '/tmp/a.mp4', speed: 1.5, loop: true);
    await takeOver();

    expect(handler.calls.last, isNot(contains('load')));
    expect(
        handler.calls.firstWhere((c) => c.startsWith('load:')), contains('ready=true'));
  });

  test('보던 것과 다르면 나갈 때 읽는다', () async {
    await provider.prepare(
        absolutePath: '/tmp/a.mp4', speed: 1.0, loop: false);
    await takeOver(); // speed=1.5, loop=true

    expect(handler.calls.firstWhere((c) => c.startsWith('load:')),
        contains('ready=false'));
  });

  test('이어 듣는 중에는 미리 읽기가 소리를 건드리지 않는다', () async {
    await takeOver();
    handler.calls.clear();

    await provider.prepare(
        absolutePath: '/tmp/b.mp4', speed: 1.0, loop: false);

    expect(handler.calls, isEmpty);
    expect(provider.current!.title, '카페에서');
  });

  test('소리를 읽는 동안에도 줄은 이미 떠 있다', () async {
    // 다 읽은 뒤에 띄웠더니 한 템포 늦게 생겼다(5차, 사용자 신고).
    handler.loadGate = Completer<void>();
    final pending = takeOver();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(provider.isActive, isTrue, reason: '기다리는 동안에도 줄은 떠 있다');
    expect(provider.current!.playing, isTrue);

    handler.loadGate!.complete();
    await pending;
    expect(provider.isActive, isTrue);
  });

  test('다른 소리가 나면 듣던 것이 멈춘다', () async {
    // 이어 듣는 동안 쇼츠나 문장 소리가 겹쳐 울렸다(5차, 사용자 요청).
    await takeOver();

    await AudioFocus.instance.claim();

    expect(provider.isActive, isFalse);
    expect(handler.calls, contains('stop'));
  });

  test('듣는 중이 아니면 소리 쪽을 괜히 깨우지 않는다', () async {
    await AudioFocus.instance.claim();

    expect(handlerCalls, 0);
    expect(handler.calls, isEmpty);
  });

  test('소리 쪽이 늦게 올라와도 한 번 더 해 본다', () async {
    var tries = 0;
    final late_ = BackgroundPlaybackProvider(handler: () async {
      tries++;
      if (tries == 1) throw StateError('아직 안 올라옴');
      return handler;
    });
    addTearDown(late_.dispose);

    await late_.takeOver(
      clipId: 1,
      title: '카페에서',
      absolutePath: '/tmp/a.mp4',
      position: Duration.zero,
      speed: 1,
    );

    expect(tries, 2);
    expect(late_.isActive, isTrue, reason: '첫 진입에서도 줄이 떠야 한다');
  });

}
