import 'package:parrokit/core/shared/utils/app_logger.dart';
import '../../domain/models/video_generation_models.dart';
import '../../domain/repositories/video_generation_repository.dart';
import '../data_sources/video_remote_data_source.dart';

class VideoGenerationRepositoryImpl implements VideoGenerationRepository {
  final VideoRemoteDataSource remoteDataSource;

  const VideoGenerationRepositoryImpl(this.remoteDataSource);

  @override
  Future<String> generateVideo({
    required String dialogue,
    required String scenePrompt,
    required String ratio,
    int duration = 5,
    String model = veo31LiteModelId,
    String resolution = '720p',
    bool debug = false,
  }) async {
    AppLogger.i(
        '[VideoRepository][Generate] start ratio=$ratio duration=$duration model=$model resolution=$resolution debug=$debug');
    try {
      final result = await remoteDataSource.generateVideo(
        dialogue: dialogue,
        scenePrompt: scenePrompt,
        ratio: ratio,
        duration: duration,
        model: model,
        resolution: resolution,
        debug: debug,
      );
      AppLogger.i('[VideoRepository][Generate] success');
      return result;
    } catch (e, stack) {
      AppLogger.e('[VideoRepository][Generate] error reason=$e',
          error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> checkVideoOperation(String operationName) async {
    AppLogger.i(
        '[VideoRepository][CheckOperation] start operationName=$operationName');
    try {
      final result = await remoteDataSource.checkVideoOperation(operationName);
      AppLogger.i('[VideoRepository][CheckOperation] success');
      return result;
    } catch (e, stack) {
      AppLogger.e('[VideoRepository][CheckOperation] error reason=$e',
          error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<List<VideoGenerationRecord>> listRecentVideoGenerations() async {
    AppLogger.i('[VideoRepository][ListRecent] start');
    try {
      final result = await remoteDataSource.listRecentVideoGenerations();
      AppLogger.i(
          '[VideoRepository][ListRecent] success count=${result.length}');
      return result;
    } catch (e, stack) {
      AppLogger.e('[VideoRepository][ListRecent] error reason=$e',
          error: e, stackTrace: stack);
      rethrow;
    }
  }
}
