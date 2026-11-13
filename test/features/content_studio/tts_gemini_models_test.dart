import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_gemini_models.dart';

void main() {
  test('종료된 Gemini TTS 모델은 목록에 없고 기본 모델은 목록에 있다', () {
    final ids = geminiModels.map((m) => m.id).toSet();
    expect(ids, contains(defaultGeminiTtsModelId));
    for (final retired in [
      'gemini-2.5-flash-preview-tts',
      'gemini-3.1-flash-tts-preview',
      'gemini-2.5-pro-preview-tts',
    ]) {
      expect(ids, isNot(contains(retired)));
    }
  });

  test('앱 가격표는 서버 pricing.ts와 같다', () {
    // 앱은 예상 패롯을, 서버는 실제 차감을 정한다. 둘이 다르면 화면과 실제가 어긋난다.
    final server = File('functions/src/pricing.ts').readAsStringSync();
    for (final model in geminiModels) {
      expect(server, contains('"${model.id}": ${model.charsPerParrot},'),
          reason: model.id);
    }
    expect(server,
        contains('const GEMINI_TTS_DEFAULT_MODEL = "$defaultGeminiTtsModelId";'));
  });
}
