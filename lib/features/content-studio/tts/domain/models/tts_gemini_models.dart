class TtsGeminiModel {
  final String id;
  final String name;
  final String description;

  /// 이 모델 기준 1패롯이 커버하는 글자 수 (70% 마진 기준).
  final int charsPerParrot;

  const TtsGeminiModel({
    required this.id,
    required this.name,
    required this.description,
    required this.charsPerParrot,
  });
}

class TtsGeminiVoice {
  final String id;
  final String name;
  final String description;

  const TtsGeminiVoice({
    required this.id,
    required this.name,
    required this.description,
  });
}

/// Gemini TTS 기본 모델. 서버(functions/src/pricing.ts)의 기본값과 같다.
const defaultGeminiTtsModelId = 'gemini-3.8-flash-tts';

/// 예전 셋(2.5 Flash·2.5 Pro·3.1 Flash 프리뷰)은 Gemini API에서 2026-11-17에
/// 종료된다(5차). 대체 모델 둘만 둔다. 가격은 서버 pricing.ts와 같아야 한다.
const List<TtsGeminiModel> geminiModels = [
  TtsGeminiModel(
    id: 'gemini-3.8-flash-tts',
    name: 'Gemini 3.8 Flash TTS',
    description: '자연스러운 억양, 대부분의 문장에 알맞아요',
    charsPerParrot: 60,
  ),
  TtsGeminiModel(
    id: 'gemini-3.8-flash-lite-tts',
    name: 'Gemini 3.8 Flash-Lite TTS',
    description: '가볍고 빨라요. 같은 패롯으로 두 배 길이',
    charsPerParrot: 120,
  ),
];

const List<TtsGeminiVoice> geminiVoices = [
  TtsGeminiVoice(
    id: 'Aoede',
    name: 'Aoede',
    description: '차분하고 명확한 음성',
  ),
  TtsGeminiVoice(
    id: 'Puck',
    name: 'Puck',
    description: '에너지 넘치는 친근한 음성',
  ),
  TtsGeminiVoice(
    id: 'Charon',
    name: 'Charon',
    description: '진중하고 신뢰감 있는 음성',
  ),
  TtsGeminiVoice(
    id: 'Kore',
    name: 'Kore',
    description: '부드럽고 따뜻한 음성',
  ),
  TtsGeminiVoice(
    id: 'Fenrir',
    name: 'Fenrir',
    description: '강력하고 묵직한 음성',
  ),
];
