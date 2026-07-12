/// Provider별 튜닝 파라미터를 분리해서 담는 상태 객체들.
///
/// 이전에는 [TtsProvider]가 voiceId/modelId 등을 하나의 필드로 공유해서,
/// provider를 전환할 때마다 이전 값을 수동으로 리셋해야 했고 리셋을 빠뜨리면
/// 다른 provider로 값이 새어 들어가는 버그가 반복됐다. 각 provider 전용
/// 필드만 담은 객체로 나누면 애초에 다른 provider의 필드가 존재하지 않으므로
/// 이런 버그가 구조적으로 불가능해진다.
class GoogleTtsSettings {
  String voiceId = '';
  double speakingRate = 1.0;
  double pitch = 0.0;
}

class ElevenLabsTtsSettings {
  String voiceId = '';
  String? modelId;
  double stability = 0.50;
  double similarityBoost = 0.75;
  double style = 0.0;
  bool useSpeakerBoost = true;
}

class GeminiTtsSettings {
  String voiceId = '';
  String? modelId;
}
