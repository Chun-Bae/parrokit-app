// 새 플레이어를 화면 밖에서 들고 있는 곳(5차 4단계).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/player/native_player.dart';
import 'package:parrokit/core/state/provider/clip_playback_holder.dart';
import 'package:parrokit/features/collection/clip/player/presentation/engine/native_clip_player_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late ClipPlaybackHolder holder;

  NativeClipPlayerEngine makeEngine() {
    const channel = MethodChannel('test/holder_player');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'create') return {'textureId': 1};
      return null;
    });
    return NativeClipPlayerEngine(
      player: NativePlayerController(
        channel: channel,
        eventsOf: (_) => const Stream<dynamic>.empty(),
      ),
    );
  }

  setUp(() {
    calls = [];
    holder = ClipPlaybackHolder(engineOf: makeEngine);
  });

  tearDown(() => holder.dispose());

  test('아무것도 안 들고 있으면 줄을 띄우지 않는다', () {
    expect(holder.isActive, isFalse);
    expect(holder.clipId, isNull);
  });

  test('같은 클립이면 쓰던 플레이어를 그대로 준다', () {
    final first = holder.engineFor(clipId: 7, title: '카페에서');
    final again = holder.engineFor(clipId: 7, title: '카페에서');

    expect(identical(first.engine, again.engine), isTrue);
    expect(first.loaded, isFalse, reason: '처음에는 읽은 것이 없다');
    expect(holder.isActive, isTrue);
    expect(holder.clipId, 7);
  });

  test('다른 클립이면 새로 만든다', () {
    final first = holder.engineFor(clipId: 7, title: '하나');
    final second = holder.engineFor(clipId: 8, title: '둘');

    expect(identical(first.engine, second.engine), isFalse);
    expect(holder.clipId, 8);
  });

  test('닫으면 들고 있던 것을 놓는다', () async {
    holder.engineFor(clipId: 7, title: '카페에서');

    await holder.stop();

    expect(holder.isActive, isFalse);
    expect(holder.clipId, isNull);
    expect(holder.engine, isNull);
  });

  test('바뀌면 알린다', () {
    var notified = 0;
    holder.addListener(() => notified++);

    holder.engineFor(clipId: 7, title: '카페에서');

    expect(notified, greaterThan(0));
  });
}
