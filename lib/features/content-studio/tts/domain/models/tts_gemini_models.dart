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

const List<TtsGeminiModel> geminiModels = [
  TtsGeminiModel(
    id: 'gemini-2.5-flash-preview-tts',
    name: 'Gemini 2.5 Flash TTS',
    description: '빠르고 범용적인 음성 합성에 적합',
    charsPerParrot: 120,
  ),
  TtsGeminiModel(
    id: 'gemini-3.1-flash-tts-preview',
    name: 'Gemini 3.1 Flash TTS (프리뷰)',
    description: '최신 프리뷰 모델',
    charsPerParrot: 60,
  ),
  TtsGeminiModel(
    id: 'gemini-2.5-pro-preview-tts',
    name: 'Gemini 2.5 Pro TTS',
    description: '최상의 품질과 복잡한 추론',
    charsPerParrot: 60,
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
