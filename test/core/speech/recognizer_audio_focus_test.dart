// 따라 말하기를 시작하면 듣던 소리를 먼저 멈춘다(5차).
//
// 안 멈추면 마이크가 그 소리를 같이 듣고(인식이 더러워진다), 사용자도
// 자기 말과 겹쳐 들린다. 인식기는 플러그인이 있어야 돌아가므로 여기서는
// 그 차례가 코드에 남아 있는지와 AudioFocus 자체를 지킨다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/audio_focus.dart';

void main() {
  test('인식을 시작하기 전에 듣던 소리를 멈춘다', () {
    final source = File('lib/core/speech/phrase_recognizer.dart')
        .readAsStringSync();
    final claimAt = source.indexOf('AudioFocus.instance.claim()');
    final listenAt = source.indexOf('_speech.listen(');

    expect(claimAt, greaterThan(0), reason: '멈추라고 알리는 곳이 있어야 한다');
    expect(listenAt, greaterThan(claimAt), reason: '듣기 시작하기 전에 멈춘다');
  });

  test('소리를 내는 곳이 여럿이어도 모두 멈춘다', () async {
    final stopped = <String>[];
    Future<void> one() async => stopped.add('하나');
    Future<void> two() async => stopped.add('둘');
    AudioFocus.instance.registerBackground(one);
    AudioFocus.instance.registerBackground(two);
    addTearDown(() {
      AudioFocus.instance.unregisterBackground(one);
      AudioFocus.instance.unregisterBackground(two);
    });

    await AudioFocus.instance.claim();

    expect(stopped, ['하나', '둘']);
  });

  test('하나가 넘어져도 나머지는 멈춘다', () async {
    final stopped = <String>[];
    Future<void> bad() async => throw StateError('못 멈춤');
    Future<void> good() async => stopped.add('나머지');
    AudioFocus.instance.registerBackground(bad);
    AudioFocus.instance.registerBackground(good);
    addTearDown(() {
      AudioFocus.instance.unregisterBackground(bad);
      AudioFocus.instance.unregisterBackground(good);
    });

    await AudioFocus.instance.claim();

    expect(stopped, ['나머지']);
  });
}
