// 소리를 내는 곳은 모두 AudioFocus를 거쳐야 한다(5차).
//
// 이어 듣기(백그라운드 재생)와 겹쳐 울리는 문제를 여러 번 고쳤는데, 그때마다
// 새로 만든 소리 하나가 빠져 있었다(쇼츠 → 문장 듣기 → 따라 말하기 →
// 스튜디오 미리 듣기 → 자막 만들기 미리보기). 새 소리를 더할 때 이 테스트가
// 먼저 깨지게 둔다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 소리나 영상을 트는 꾸러미를 가져다 쓰는 파일.
const _audioPackages = [
  'package:just_audio/',
  'package:audioplayers/',
  'package:flutter_tts/',
  'package:video_player/',
  'package:audio_service/',
];

/// AudioFocus를 거치는 것으로 이미 확인한 파일.
///
/// - claim(): 소리를 내기 전에 남이 듣던 것을 멈춘다.
/// - registerBackground(): 자기 소리를 남이 멈출 수 있게 맡긴다.
/// - 아래 '맡긴 쪽'은 자기를 들고 있는 곳(홀더·프로바이더·화면)이 대신 건다.
const _viaOwner = {
  // 클립 플레이어: ClipPlaybackHolder가 claim·register를 맡는다.
  'lib/core/shared/player/native_player.dart',
  'lib/features/collection/clip/player/presentation/clip_player_view_model.dart',
  'lib/features/collection/clip/player/presentation/engine/clip_player_engine.dart',
  'lib/features/collection/clip/player/presentation/engine/native_clip_player_engine.dart',
  // 쇼츠: shorts_screen이 들어올 때 claim한다.
  'lib/features/collection/clip/shorts/presentation/widgets/shorts_page.dart',
  'lib/features/collection/clip/shorts/presentation/sections/shorts_page_control_section.dart',
  // 이어 듣기 쪽: BackgroundPlaybackProvider가 claim·register를 맡는다.
  'lib/core/shared/utils/audio_bg.dart',
  // 영상 길이·썸네일만 읽고 소리를 내지 않는다.
  'lib/features/content-studio/captioning/data/services/video_meta_service.dart',
  // 영상 만들기는 입구가 숨겨져 있다(kVideoStudioEnabled).
  'lib/features/content-studio/video/presentation/video_screen.dart',
  // 자막 만들기: 트는 곳은 file_section 하나뿐이고(거기서 claim한다),
  // 아래는 받은 컨트롤러로 그리거나 자리를 옮기기만 한다.
  'lib/features/content-studio/captioning/presentation/sections/segments_section.dart',
  'lib/features/content-studio/captioning/presentation/widgets/audio_waveform_bar.dart',
  'lib/features/content-studio/captioning/presentation/widgets/file_hero_card.dart',
  'lib/features/content-studio/captioning/presentation/widgets/video_controls_bar.dart',
  'lib/features/content-studio/captioning/presentation/widgets/segment_card.dart',
  'lib/features/content-studio/captioning/presentation/widgets/picked_state.dart',
};

bool _usesAudioPackage(String code) =>
    _audioPackages.any((p) => code.contains("import '$p"));

void main() {
  test('소리를 내는 파일은 AudioFocus를 거치거나, 거는 곳이 정해져 있다', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      final code = entity.readAsStringSync();
      if (!_usesAudioPackage(code)) continue;
      if (_viaOwner.contains(path)) continue;
      if (code.contains('AudioFocus.instance.claim()') ||
          code.contains('AudioFocus.instance.registerBackground')) {
        continue;
      }
      offenders.add(path);
    }

    expect(offenders, isEmpty,
        reason: '소리를 내는 새 파일이 생겼어요. AudioFocus.claim()을 부르거나, '
            '이 테스트의 _viaOwner에 "누가 대신 거는지"를 적어 주세요:\n'
            '${offenders.join('\n')}');
  });

  test('맡긴 쪽으로 적어 둔 파일은 스스로 소리를 틀지 않는다', () {
    // '누가 대신 건다'고 적어 둔 파일이 나중에 직접 재생을 시작하면
    // 그 소리는 아무도 안 멈춘다.
    const ownersThatPlay = {
      // 이 둘은 들고 있는 쪽이 claim·register까지 맡는다.
      'lib/core/shared/player/native_player.dart',
      'lib/features/collection/clip/player/presentation/clip_player_view_model.dart',
      'lib/features/collection/clip/player/presentation/engine/clip_player_engine.dart',
      'lib/features/collection/clip/player/presentation/engine/native_clip_player_engine.dart',
      'lib/features/collection/clip/shorts/presentation/widgets/shorts_page.dart',
      'lib/features/collection/clip/shorts/presentation/sections/shorts_page_control_section.dart',
      'lib/core/shared/utils/audio_bg.dart',
      'lib/features/content-studio/video/presentation/video_screen.dart',
    };
    for (final path in _viaOwner.difference(ownersThatPlay)) {
      final code = File(path).readAsStringSync();
      expect(code.contains('.play()'), isFalse, reason: path);
    }
  });

  test('맡긴 쪽 목록에 적힌 파일은 실제로 있다', () {
    // 파일을 옮기거나 지우면 목록도 같이 고치게 한다.
    for (final path in _viaOwner) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
