// 스튜디오에서 소리를 내는 곳도 듣던 것을 멈춘다(5차).
//
// 만든 음성 미리 듣기와 목소리 미리듣기는 just_audio를 따로 쓴다.
// 이어 듣던 클립과 겹쳐 울리지 않게 먼저 멈춘다. 플러그인이 있어야 돌아가는
// 코드라 여기서는 그 차례가 남아 있는지를 지킨다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectClaimBeforePlay(String path, String playCall) {
    final source = File(path).readAsStringSync();
    final claimAt = source.indexOf('AudioFocus.instance.claim()');
    final playAt = source.indexOf(playCall);

    expect(claimAt, greaterThan(0), reason: '$path: 멈추라고 알리는 곳이 없다');
    expect(playAt, greaterThan(claimAt),
        reason: '$path: 틀기 전에 멈춰야 한다');
  }

  test('만든 음성 미리 듣기', () {
    expectClaimBeforePlay(
      'lib/features/content-studio/tts/presentation/widgets/tts_audio_player_widget.dart',
      'await _player.play()',
    );
  });

  test('목소리 미리듣기', () {
    expectClaimBeforePlay(
      'lib/features/content-studio/tts/presentation/widgets/tts_voice_selection_sheet.dart',
      'await _previewPlayer.play()',
    );
  });
}
