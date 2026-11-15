// 음성 만들기 화면의 말(5차).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/tts/presentation/screens/tts_screen.dart';

void main() {
  test('목록을 못 불러와도 만들 수 있다는 것을 알린다', () {
    // 버튼만 켜져 있으면 눌러도 되는지 몰라 망설인다. 서버가 기본 목소리를
    // 고른다는 것을 적어 둔다.
    expect(ttsDefaultVoiceNotice, contains('기본 목소리'));
    expect(ttsDefaultVoiceNotice, contains('못 불러왔어요'));
    expect(ttsDefaultVoiceNotice, endsWith('.'));
  });

  test('화면 말에 내부 용어를 쓰지 않는다', () {
    for (final word in ['TTS', 'voice', '보이스', '생성']) {
      expect(ttsDefaultVoiceNotice.contains(word), isFalse,
          reason: '"$word"는 화면 말이 아니다');
    }
  });
}
