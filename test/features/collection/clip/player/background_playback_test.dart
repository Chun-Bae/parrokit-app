// 앱을 내리면 알아서 소리가 이어지고, 돌아오면 영상으로 되돌아온다(5차, 사용자 요청).
//
// 전에는 '소리만 듣기' 버튼을 눌러 둔 사람만 이어졌다. 그 버튼은 없앴다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path).readAsStringSync();

void main() {
  test('소리만 듣기 버튼과 안내가 화면에서 사라졌다', () {
    final screen = _code(
        'lib/features/collection/clip/player/presentation/clip_player_screen.dart');

    expect(screen.contains('audio-only-toggle'), isFalse);
    expect(screen.contains('audioOnlyLabel'), isFalse);
    expect(screen.contains('audio-only-notice'), isFalse);
    expect(
        File('lib/features/collection/clip/player/presentation/audio_only_label.dart')
            .existsSync(),
        isFalse);
  });

  test('앱을 내리면 소리를 이어서 틀고, 돌아오면 영상으로 되돌린다', () {
    final vm = _code(
        'lib/features/collection/clip/player/presentation/clip_player_view_model.dart');

    // 내릴 때: 틀고 있었으면 소리만 모드로 들어가며 바로 이어서 튼다.
    expect(vm, contains('AppLifecycleState.paused'));
    expect(vm, contains('enterAudioOnlyMode(autoPlay: true)'));
    // 돌아올 때: 영상으로 되돌리고 이어서 튼다.
    expect(vm, contains('AppLifecycleState.resumed'));
    expect(vm, contains('exitAudioOnlyMode()'));
    expect(vm, contains('_wasPlayingBeforeBackground'));
  });

  test('멈춰 둔 영상은 내려도 소리가 나지 않는다', () {
    final vm = _code(
        'lib/features/collection/clip/player/presentation/clip_player_view_model.dart');
    // 틀고 있을 때만 들어간다.
    expect(vm, contains('if (!playing) return;'));
  });

  test('소리만 모드는 이어서 틀지, 멈춰 두지 고를 수 있다', () {
    final mixin = _code(
        'lib/features/collection/clip/player/presentation/view_model/audio_mode_mixin.dart');
    expect(mixin, contains('Future<void> enterAudioOnlyMode({bool autoPlay = false})'));
    expect(mixin, contains('mutableBgPlaying = true;'));
  });
}
