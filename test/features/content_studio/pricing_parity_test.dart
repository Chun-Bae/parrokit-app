// 앱의 패롯 가격 표가 서버(functions/src/pricing.ts)와 같은지 본다.
//
// 앱은 이 표로 "예상 패롯"을 보여주고 실제로 깎는 양은 서버가 정한다. 한쪽만
// 바꾸면 보여준 값과 깎인 값이 달라진다. 두 파일을 읽어 맞춰 본다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/presentation/providers/captioning_provider.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_elevenlabs_models.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_gemini_models.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_google_models.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';

final String _pricing = File('functions/src/pricing.ts').readAsStringSync();

/// `const NAME: Record<string, number> = { "id": 20, ... };`를 읽는다.
Map<String, int> _numberTable(String name) {
  final block = RegExp('const $name[^=]*=\\s*\\{([^}]*)\\}').firstMatch(_pricing)!;
  return {
    for (final m in RegExp(r'"([^"]+)":\s*(\d+)').allMatches(block.group(1)!))
      m.group(1)!: int.parse(m.group(2)!),
  };
}

void main() {
  test('Google TTS 1패롯당 글자 수', () {
    final server = RegExp(r'GOOGLE_TTS_CHARS_PER_PARROT = (\d+);')
        .firstMatch(_pricing)!
        .group(1);
    expect(googleTtsCharsPerParrot, int.parse(server!));
  });

  test('ElevenLabs 모델별 1패롯당 글자 수', () {
    expect(
      {for (final m in elevenLabsModels) m.id: m.charsPerParrot},
      _numberTable('ELEVENLABS_CHARS_PER_PARROT'),
    );
  });

  test('Gemini TTS 모델별 1패롯당 글자 수와 기본 모델', () {
    expect(
      {for (final m in geminiModels) m.id: m.charsPerParrot},
      _numberTable('GEMINI_TTS_CHARS_PER_PARROT'),
    );
    final serverDefault = RegExp(r'GEMINI_TTS_DEFAULT_MODEL = "([^"]+)"')
        .firstMatch(_pricing)!
        .group(1);
    expect(defaultGeminiTtsModelId, serverDefault);
  });

  test('영상 모델별 초당 패롯(720p·1080p)', () {
    final block = RegExp(r'const VEO_COST_PER_SECOND[^=]*=\s*\{([\s\S]*?)\};')
        .firstMatch(_pricing)!
        .group(1)!;
    final server = {
      for (final m in RegExp(r'"([^"]+)":\s*\{p720:\s*(\d+),\s*p1080:\s*(\d+)\}')
          .allMatches(block))
        m.group(1)!: [int.parse(m.group(2)!), int.parse(m.group(3)!)],
    };
    expect(
      {
        for (final m in veo31Models)
          m.id: [m.costPerSecond720p, m.costPerSecond1080p],
      },
      server,
    );
  });

  test('자동 자막: 10초에 1패롯, 올림(서버 captionCost와 같은 식)', () {
    expect(_pricing, contains('Math.ceil(durationMs / 1000)'));
    expect(_pricing, contains('Math.floor((seconds + 9) / 10)'));
    expect(captionParrotCost(0), 0);
    expect(captionParrotCost(1), 1);
    expect(captionParrotCost(10000), 1);
    expect(captionParrotCost(10001), 2);
    expect(captionParrotCost(300000), 30);
  });
}
