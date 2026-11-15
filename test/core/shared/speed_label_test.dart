// 속도 표시는 화면마다 같은 말로 적는다. 예전에는 '1.00x'처럼 영문 x였다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/speed_label.dart';
import 'package:parrokit/features/collection/clip/player/domain/player_state.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('쓸데없는 0은 떼고 배로 적는다', () {
    expect(speedLabel(1), '1배');
    expect(speedLabel(1.0), '1배');
    expect(speedLabel(0.5), '0.5배');
    expect(speedLabel(1.25), '1.25배');
    expect(speedLabel(2), '2배');
    expect(speedLabel(0.25), '0.25배');
  });

  test('플레이어 속도 이름도 같은 함수를 쓴다', () {
    expect(PlaybackRates.label(1.5), '1.5배');
  });

  test('화면들이 손으로 x를 적지 않는다', () {
    const paths = [
      'lib/features/collection/clip/player/presentation/widgets/speed_menu.dart',
      'lib/features/content-studio/captioning/presentation/widgets/picked_state.dart',
      'lib/features/content-studio/tts/presentation/screens/tts_screen.dart',
    ];
    for (final path in paths) {
      final code = _code(path);
      expect(code, contains('speedLabel('), reason: path);
      expect(code, isNot(contains("toStringAsFixed(2)}x")), reason: path);
    }
  });

  test('TTS 속도 제목에 범위를 적지 않는다', () {
    final code =
        _code('lib/features/content-studio/tts/presentation/screens/tts_screen.dart');
    expect(code, isNot(contains('속도 (0.25배 ~ 4.0배)')));
    expect(code, contains("label: '속도'"));
  });
}
