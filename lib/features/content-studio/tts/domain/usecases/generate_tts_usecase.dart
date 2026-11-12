import '../repositories/tts_generation_repository.dart';
import '../validators/tts_validator.dart';

class GenerateTtsUseCase {
  final TtsGenerationRepository repository;

  const GenerateTtsUseCase(this.repository);

  Future<String> call({
    required String text, 
    required String language,
    TtsProviderType provider = TtsProviderType.google,
    String? voiceId,
    String? modelId,
    double? speakingRate,
    double? pitch,
    ElevenLabsVoiceSettings? elevenLabsSettings,
    bool serverCharge = false,
    void Function(int chargedParrots)? onCharged,
  }) async {
    TtsValidator.validateText(text);
    return repository.generateTts(
      text: text, 
      language: language,
      provider: provider,
      voiceId: voiceId,
      modelId: modelId,
      speakingRate: speakingRate,
      pitch: pitch,
      elevenLabsSettings: elevenLabsSettings,
      serverCharge: serverCharge,
      onCharged: onCharged,
    );
  }
}
