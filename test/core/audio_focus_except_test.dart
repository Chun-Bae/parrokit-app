// 소리를 내려는 쪽이 자기 자신을 멈추지 않는다(5차 320).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/audio_focus.dart';

void main() {
  test('claim은 등록된 다른 소리만 멈춘다', () async {
    final stopped = <String>[];
    Future<void> other() async => stopped.add('other');
    Future<void> mine() async => stopped.add('mine');

    AudioFocus.instance
      ..registerBackground(other)
      ..registerBackground(mine);
    addTearDown(() {
      AudioFocus.instance
        ..unregisterBackground(other)
        ..unregisterBackground(mine);
    });

    await AudioFocus.instance.claim(except: mine);
    expect(stopped, ['other'], reason: '나는 그대로 울려야 한다');

    stopped.clear();
    await AudioFocus.instance.claim();
    expect(stopped, ['other', 'mine'], reason: '빼지 않으면 모두 멈춘다');
  });

  test('메서드 tear-off도 자기 자신으로 알아본다', () async {
    // 위젯은 `claim(except: _stopSpeaking)`처럼 메서드를 넘긴다. Dart에서
    // tear-off는 부를 때마다 새 객체라, identical로 가리면 자기 자신을
    // 못 알아보고 스스로 멈춘다(5차 320에 실제로 그랬다).
    final probe = _Speaker();
    AudioFocus.instance.registerBackground(probe.stop);
    addTearDown(() => AudioFocus.instance.unregisterBackground(probe.stop));

    await AudioFocus.instance.claim(except: probe.stop);
    expect(probe.stopped, 0);

    await AudioFocus.instance.claim();
    expect(probe.stopped, 1);
  });

  test('읽어 주기 위젯은 자기 정지 콜백을 빼고 차례를 가져온다', () {
    // 전에는 켜자마자 자기 콜백에 걸려 꺼졌다.
    final code = File('lib/core/shared/widgets/speak_controls.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('claim(except: _stopSpeaking)'));
    expect(code, contains('registerBackground(_stopSpeaking)'));
  });
}

class _Speaker {
  int stopped = 0;
  Future<void> stop() async => stopped++;
}
