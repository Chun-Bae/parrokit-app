import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import '../../domain/models/video_generation_models.dart';

class VideoRemoteDataSource {
  /// 안 주면 FirebaseFunctions.instance를 쓴다.
  VideoRemoteDataSource({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

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
        '[VideoDataSource][Generate] start ratio=$ratio duration=$duration model=$model resolution=$resolution debug=$debug');
    try {
      final prompt = _buildPrompt(
        dialogue: dialogue,
        scenePrompt: scenePrompt,
      );
      final callable = _functions.httpsCallable('generateVideo');
      final result = await callable.call<Map<String, dynamic>>({
        'prompt': prompt,
        'aspectRatio': ratio,
        'duration': duration,
        'model': model,
        // 서버는 modelId를 읽는다. 전에는 model만 보내서 무엇을 골라도
        // 서버 기본값(Lite)으로 만들어졌다.
        'modelId': model,
        'resolution': resolution,
        'debug': debug,
        // 패롯은 서버가 깎는다. 실패하면 서버가 돌려준다.
        'serverCharge': true,
      });

      final operationName = result.data['operationName'] as String;
      AppLogger.i(
          '[VideoDataSource][Generate] success operationName=$operationName');
      return operationName;
    } catch (e, stack) {
      AppLogger.e('[VideoDataSource][Generate] error reason=$e',
          error: e, stackTrace: stack);
      throw Exception('Failed to generate video: $e');
    }
  }

  String _buildPrompt({
    required String dialogue,
    required String scenePrompt,
  }) {
    final parts = <String>[];

    if (scenePrompt.trim().isNotEmpty) {
      parts.add(scenePrompt.trim());
    }

    if (dialogue.trim().isNotEmpty) {
      parts.add(
        '대화는 아래 영어 스크립트를 정확히 그대로 사용해야 한다:\n'
        '$dialogue',
      );
    }

    if (parts.isEmpty) {
      return scenePrompt.trim();
    }

    return parts.join('\n\n');
  }

  Future<Map<String, dynamic>> checkVideoOperation(String operationName) async {
    AppLogger.i(
        '[VideoDataSource][CheckOperation] start operationName=$operationName');
    try {
      final callable = _functions.httpsCallable('getVideoOperationStatus');
      final result = await callable.call<Map<String, dynamic>>({
        'operationName': operationName,
      });

      AppLogger.i(
          '[VideoDataSource][CheckOperation] success done=${result.data['done']}');
      return Map<String, dynamic>.from(result.data);
    } catch (e, stack) {
      AppLogger.e('[VideoDataSource][CheckOperation] error reason=$e',
          error: e, stackTrace: stack);
      throw Exception('Failed to check video operation: $e');
    }
  }

  Future<List<VideoGenerationRecord>> listRecentVideoGenerations() async {
    AppLogger.i('[VideoDataSource][ListRecent] start');
    try {
      final callable = _functions.httpsCallable('listVideoGenerations');
      final result = await callable.call<Map<String, dynamic>>();
      final items = result.data['items'];
      if (items is! List) {
        return const [];
      }

      final records = items
          .whereType<Map>()
          .map((item) => VideoGenerationRecord.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((record) => record.generationId.isNotEmpty)
          .toList(growable: false);

      AppLogger.i(
          '[VideoDataSource][ListRecent] success count=${records.length}');
      return records;
    } catch (e, stack) {
      AppLogger.e('[VideoDataSource][ListRecent] error reason=$e',
          error: e, stackTrace: stack);
      throw Exception('Failed to list recent video generations: $e');
    }
  }
}
