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
