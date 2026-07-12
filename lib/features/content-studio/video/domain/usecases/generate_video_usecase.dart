import '../models/video_generation_models.dart';
import '../repositories/video_generation_repository.dart';
import '../validators/video_validator.dart';

class GenerateVideoUseCase {
  final VideoGenerationRepository repository;

  const GenerateVideoUseCase(this.repository);

  Future<String> call({
    required String dialogue,
    required String scenePrompt,
    required String ratio,
    int duration = 5,
    String model = veo31LiteModelId,
    String resolution = '720p',
    bool debug = false,
  }) async {
    VideoValidator.validatePrompts(
        dialogue: dialogue, scenePrompt: scenePrompt);
    return repository.generateVideo(
      dialogue: dialogue,
      scenePrompt: scenePrompt,
      ratio: ratio,
      duration: duration,
      model: model,
      resolution: resolution,
      debug: debug,
    );
  }
}
