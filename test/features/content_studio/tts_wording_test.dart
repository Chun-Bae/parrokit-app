import 'dart:io';
// 음성 만들기 화면의 말(5차).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/tts/presentation/screens/tts_screen.dart';

void main() {
  _needsTextTests();
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

// 꺼진 '음성 만들기'의 까닭(5차 499).
//
// 읽을 글이 비면 단추가 꺼지는데 그 까닭이 어디에도 없었다. 같은 자리의
// 다른 줄(패롯 모자람·목소리 목록 실패)은 이미 까닭을 적고 있어서,
// 가장 흔한 까닭만 말이 없는 꼴이었다.
void _needsTextTests() {
  group('읽을 글이 비었을 때', () {
    test('까닭을 칸 이름 그대로 적는다', () {
      expect(ttsNeedsTextMessage, '읽을 글을 적어 주세요.');
      // 앱은 '…을 적어 주세요'로 묻는다(문장 추가·글쓰기와 같은 꼴).
      expect(ttsNeedsTextMessage, endsWith('적어 주세요.'));
    });

    test('화면이 단추 바로 위에 그 줄을 둔다', () {
      final code = File('lib/features/content-studio/tts/presentation/'
              'screens/tts_screen.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, contains("ValueKey('tts-needs-text')"));
      expect(code, contains('provider.text.trim().isEmpty'));
      // 빨강은 '다 썼다'에만 쓴다. 여기는 그냥 안내다.
      final at = code.indexOf("ValueKey('tts-needs-text')");
      final around = code.substring(at, at + 200);
      expect(around.contains('colorScheme.error'), isFalse);
    });
  });
}
