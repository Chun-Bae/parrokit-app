// 목소리 이름을 사람이 알아볼 수 있게 적는다(5차 412, 사용자 요청).
//
// 고르는 목록은 '목소리 1, 목소리 2…'였고, 고른 뒤 화면에는
// 'en-US-Wavenet-A'가 그대로 떴다. 둘 다 무엇인지 알 수 없는 이름이다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_google_models.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('성별과 끝 글자로 부른다', () {
    expect(googleVoiceLabel('en-US-Wavenet-A', ssmlGender: 'FEMALE'), '여성 A');
    expect(googleVoiceLabel('ko-KR-Standard-C', ssmlGender: 'MALE'), '남성 C');
    expect(googleVoiceLabel('ja-JP-Wavenet-B', ssmlGender: null), 'B');
    expect(googleVoiceLabel(''), '기본 목소리');
  });

  test('목록과 화면이 같은 이름을 쓴다', () {
    final sheet = _code('lib/features/content-studio/tts/presentation/'
        'widgets/tts_voice_selection_sheet.dart');
    final screen = _code('lib/features/content-studio/tts/presentation/'
        'screens/tts_screen.dart');
    expect(sheet, contains('googleVoiceLabel('));
    expect(screen, contains('googleVoiceLabel('));
    // 예전 이름들.
    expect(sheet, isNot(contains('목소리 1')));
    expect(screen, isNot(contains("': provider.voiceId),")));
    expect(screen, isNot(contains("'선택 (기본값)'")));
  });

  test('시트 제목에 영어 괄호를 달지 않는다', () {
    final sheet = _code('lib/features/content-studio/tts/presentation/'
        'widgets/tts_voice_selection_sheet.dart');
    expect(sheet, isNot(contains('(Model)')));
    expect(sheet, isNot(contains('(Gender)')));
  });
}
