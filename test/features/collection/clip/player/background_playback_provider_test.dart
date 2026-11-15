// 플레이어를 나가도 이어 듣기(5차, 사용자 요청).

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/state/provider/background_playback_provider.dart';

/// 실제 소리를 내지 않고 부른 것만 적어 두는 가짜 핸들러.
class _FakeHandler extends BaseAudioHandler {
  final calls = <String>[];
  Duration position = const Duration(seconds: 7);
  bool loadFails = false;

  // ignore: non_constant_identifier_names
  Future<void> loadSourceLocal({
    required String absolutePath,
    double speed = 1.0,
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
    String? title,
    String? subtitle,
    Uri? artUri,
  }) async {
    if (loadFails) throw StateError('못 읽음');
    calls.add('load:$absolutePath speed=$speed loop=$loop title=$title');
  }

  @override
  Future<void> play() async {
    calls.add('play');
    playbackState.add(PlaybackState(playing: true));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playbackState.add(PlaybackState(playing: false));
  }

  @override
  Future<void> seek(Duration p) async => calls.add('seek:${p.inSeconds}');

  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  late _FakeHandler handler;
  late BackgroundPlaybackProvider provider;

  setUp(() {
    handler = _FakeHandler();
    provider = BackgroundPlaybackProvider(handler: () async => handler);
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
}
