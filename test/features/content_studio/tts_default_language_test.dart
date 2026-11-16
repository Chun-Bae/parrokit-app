// 음성 만들기를 열면 배우는 말로 시작한다(5차 360).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/learning_languages.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_language.dart';

void main() {
  test('처음 고르는 언어는 배우는 말 목록의 첫 언어다', () {
    final learning = availableLearningLanguages.first;
    expect(learning.code, 'en');
    expect(defaultTtsLanguageCode, 'en-US');
  });

  test('그 언어가 음성 목록에 있어야 한다', () {
    expect(supportedTtsLanguages.map((l) => l.ttsCode),
        contains(defaultTtsLanguageCode));
  });

  test('음성 목록은 배우는 말을 모두 담는다', () {
    final voices = supportedTtsLanguages.map((l) => l.mlKitCode).toSet();
    for (final learning in availableLearningLanguages) {
      expect(voices, contains(learning.code), reason: learning.label);
    }
  });
}
