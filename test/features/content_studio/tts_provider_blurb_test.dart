// 어느 목소리 엔진을 고를지 알려 준다(5차 413, 사용자 요청).
//
// 맨 위 탭에는 'Google Cloud · ElevenLabs · Gemini'라는 회사 이름만 있었다.
// 무엇이 다른지, 어느 쪽이 패롯을 더 쓰는지 알 수 없어 고를 수가 없었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_elevenlabs_models.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_gemini_models.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_google_models.dart';
import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';
import 'package:parrokit/features/content-studio/tts/presentation/tts_provider_text.dart';

void main() {
  test('셋 다 무엇이 다른지 한 줄로 말한다', () {
    for (final type in TtsProviderType.values) {
      final blurb = ttsProviderBlurb(type);
      expect(blurb, isNotEmpty);
      expect(blurb, contains('패롯'), reason: '$type');
      // 회사 이름을 다시 적지 않는다. 탭에 이미 있다.
      expect(blurb, isNot(contains('Google')));
      expect(blurb, isNot(contains('ElevenLabs')));
      expect(blurb, isNot(contains('Gemini')));
    }
  });

  test('패롯 설명이 실제 단가 순서와 맞는다', () {
    // 1패롯이 읽는 글자 수가 많을수록 싸다.
    final elevenCheapest =
        elevenLabsModels.map((m) => m.charsPerParrot).reduce((a, b) => a > b ? a : b);
    final geminiCheapest =
        geminiModels.map((m) => m.charsPerParrot).reduce((a, b) => a > b ? a : b);
    expect(googleTtsCharsPerParrot, greaterThan(elevenCheapest),
        reason: 'Google이 가장 적게 든다고 적었다');
    expect(geminiCheapest, greaterThan(elevenCheapest),
        reason: 'ElevenLabs가 가장 많이 든다고 적었다');

    expect(ttsProviderBlurb(TtsProviderType.google), contains('가장 적게'));
    expect(ttsProviderBlurb(TtsProviderType.elevenlabs), contains('가장 많이'));
  });

  test('화면이 그 한 줄을 보여 준다', () {
    final code = File('lib/features/content-studio/tts/presentation/'
            'screens/tts_screen.dart')
        .readAsStringSync();
    expect(code, contains("ValueKey('tts-provider-blurb')"));
    expect(code, contains('ttsProviderBlurb('));
  });
}
