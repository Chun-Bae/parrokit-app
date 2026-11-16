/// Google Cloud TTS 음성 등급(모델).
///
/// Standard/WaveNet 두 등급만 채택한다. 단가가 동일(100만자당 $4)하고
/// Neural2/Chirp3/Studio 등 고가 등급은 제외해 원가를 예측 가능하게 유지한다.
class TtsGoogleModel {
  final String id;
  final String name;
  final String description;

  const TtsGoogleModel({
    required this.id,
    required this.name,
    required this.description,
  });
}

/// Standard/WaveNet 실원가(100만자당 $4) 기준 94% 마진에 맞춘 글자수.
const int googleTtsCharsPerParrot = 100;

const List<TtsGoogleModel> googleModels = [
  TtsGoogleModel(
    id: 'Standard',
    name: 'Standard',
    description: '또렷하고 안정적인 기본 음성. 합성 음성 특유의 톤',
  ),
  TtsGoogleModel(
    id: 'Wavenet',
    name: 'WaveNet',
    description: '자연스러운 억양과 리듬감의 딥러닝 음성. Standard보다 부드러움',
  ),
];

/// Google TTS `ssmlGender` 값을 사용자 표시용 라벨로 변환합니다.
String googleGenderLabel(String? ssmlGender) {
  switch (ssmlGender) {
    case 'MALE':
      return '남성';
    case 'FEMALE':
      return '여성';
    default:
      return '중립';
  }
}

/// 목소리 이름을 사람이 알아볼 수 있게 적는다(5차 412, 사용자 요청).
///
/// 전에는 고르는 목록이 '목소리 1, 목소리 2…'였고, 고른 뒤 화면에는
/// `en-US-Wavenet-A`가 그대로 떴다. 둘 다 무엇인지 알 수 없는 이름이다.
/// 구글 목소리 id는 `<언어>-<등급>-<글자>` 꼴이라 끝 글자가 목소리를
/// 가른다. 성별과 그 글자로 부른다('여성 A').
String googleVoiceLabel(String voiceId, {String? ssmlGender}) {
  final id = voiceId.trim();
  if (id.isEmpty) return '기본 목소리';
  final tail = id.split('-').last;
  if (ssmlGender == null || ssmlGender.isEmpty) return tail;
  return '${googleGenderLabel(ssmlGender)} $tail';
}
