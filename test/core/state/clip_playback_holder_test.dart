// 새 플레이어를 화면 밖에서 들고 있는 곳(5차 4단계).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/player/native_player.dart';
import 'package:parrokit/core/shared/utils/audio_focus.dart';
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

  test('열기만 하고 안 틀었으면 줄을 띄우지 않는다', () {
    // 플레이어를 열기만 해도 '듣는 중' 줄이 떴다(5차 4단계).
    holder.engineFor(clipId: 7, title: '카페에서');

    expect(holder.isActive, isFalse);
    expect(holder.clipId, 7, reason: '들고는 있다');
  });

  test('같은 클립이면 쓰던 플레이어를 그대로 준다', () {
    final first = holder.engineFor(clipId: 7, title: '카페에서');
    final again = holder.engineFor(clipId: 7, title: '카페에서');

    expect(identical(first.engine, again.engine), isTrue);
    expect(first.loaded, isFalse, reason: '처음에는 읽은 것이 없다');
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

    expect(holder.clipId, isNull);
    expect(holder.engine, isNull);
  });

  test('바뀌면 알린다', () {
    var notified = 0;
    holder.addListener(() => notified++);

    holder.engineFor(clipId: 7, title: '카페에서');

    expect(notified, greaterThan(0));
  });

  // ClipPlayerScreen.build가 engineFor를 부른다(5차 565). 그 자리에서 바로
  // 알리면 이 Provider를 듣고 있는 위젯에 markNeedsBuild가 걸려
  // 'setState() or markNeedsBuild() called during build'가 난다. 클립을
  // 열 때마다 났다.
  testWidgets('그리는 중에 불러도 터지지 않는다', (tester) async {
    var notified = 0;
    holder.addListener(() => notified++);

    // ClipPlayerScreen과 같은 모양: Provider가 위에 있고, 그 아래 위젯의
    // build가 engineFor를 부른다. 바로 알리면 이미 지어진 Provider
    // 자리에 markNeedsBuild가 걸린다.
    await tester.pumpWidget(
      ChangeNotifierProvider<ClipPlaybackHolder>.value(
        value: holder,
        child: Builder(
          builder: (context) {
            context.watch<ClipPlaybackHolder>();
            return Builder(
              builder: (inner) {
                inner.read<ClipPlaybackHolder>().engineFor(
                      clipId: 7,
                      title: '카페에서',
                    );
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(notified, greaterThan(0), reason: '미뤘어도 알리기는 한다');
  });

  test('다른 소리가 나면 들고 있던 것을 놓는다', () async {
    // 쇼츠나 문장 소리와 겹쳐 울리면 안 된다(5차).
    holder.engineFor(clipId: 7, title: '카페에서');

    await AudioFocus.instance.claim();

    expect(holder.engine, isNull);
  });

  test('들고 있는 것이 없으면 아무 일도 없다', () async {
    await AudioFocus.instance.claim();

    expect(holder.isActive, isFalse);
  });
}
