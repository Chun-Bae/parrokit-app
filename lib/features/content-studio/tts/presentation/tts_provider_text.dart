import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';

/// 어느 목소리 엔진을 고를지 알려 주는 한 줄(5차 413, 사용자 요청).
///
/// 맨 위 탭에는 'Google Cloud · ElevenLabs · Gemini'라는 회사 이름만 있었다.
/// 무엇이 다른지, 왜 셋인지, 어느 쪽이 패롯을 더 쓰는지 알 수 없어 고를
/// 수가 없었다. 1패롯이 읽어 주는 글자 수가 실제로 다르다
/// (Google 100자, Gemini 60~120자, ElevenLabs 20~40자).
String ttsProviderBlurb(TtsProviderType type) => switch (type) {
      TtsProviderType.google => '또렷하고 안정적이에요. 패롯이 가장 적게 들어요.',
      TtsProviderType.elevenlabs => '사람 목소리에 가장 가까워요. 패롯이 가장 많이 들어요.',
      TtsProviderType.gemini => '말맛을 살려 읽어요. 패롯은 중간쯤 들어요.',
    };
