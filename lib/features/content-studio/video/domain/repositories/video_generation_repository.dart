import '../models/video_generation_models.dart';

abstract class VideoGenerationRepository {
  /// 프롬프트를 바탕으로 비디오 생성을 요청하고 operationName을 반환합니다.
  Future<String> generateVideo({
    required String dialogue,
    required String scenePrompt,
    required String ratio,
    int duration = 5,
    String model = veo31LiteModelId,
    String resolution = '720p',
    bool debug = false,
  });

  /// 생성 중인 비디오의 상태를 확인합니다.
  Future<Map<String, dynamic>> checkVideoOperation(String operationName);

  /// 현재 사용자 기준 최근 생성 영상을 불러옵니다.
  Future<List<VideoGenerationRecord>> listRecentVideoGenerations();
}
