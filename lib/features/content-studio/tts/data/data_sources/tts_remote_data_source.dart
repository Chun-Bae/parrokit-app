import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
import '../../domain/repositories/tts_generation_repository.dart';

class TtsRemoteDataSource {
  Future<String> generateTts({
    required String text,
    required String language,
    TtsProviderType provider = TtsProviderType.google,
    String? voiceId,
    String? modelId,
    double? speakingRate,
    double? pitch,
    ElevenLabsVoiceSettings? elevenLabsSettings,
  }) async {
    // 1. 캐시키 생성 (파라미터 조합)
    final cacheKeyData =
        '${text}_${language}_${provider.name}_${voiceId}_${modelId}_${speakingRate}_${pitch}_${elevenLabsSettings?.toJson()}';
    // sha256으로 줄여서 파일명으로 쓴다. 전에는 String.hashCode를 썼는데
    // 그건 32비트라 서로 다른 스크립트가 같은 값이 될 수 있다. 그러면
    // 캐시 히트로 판단해서 **다른 글의 음성**을 돌려준다. 돈을 내고 쓰는
    // 기능이라 조용히 틀리면 안 된다.
    final cacheKey =
        sha256.convert(utf8.encode(cacheKeyData)).toString().substring(0, 32);
    
    final tempDir = await getTemporaryDirectory();
    final ext = provider == TtsProviderType.google ? 'mp3' : 'wav';
    final file = File('${tempDir.path}/tts_$cacheKey.$ext');

    // 2. 캐시 히트 검사
    if (await file.exists() && await file.length() > 0) {
      AppLogger.d('[TTS][Repository] Cache hit cacheKey=$cacheKey');
      return file.path;
    }

    // 3. 캐시 미스: Firebase Functions 호출
    AppLogger.i('[TTS][Repository] Calling generateTts text_length=${text.length} provider=${provider.name} voiceId=$voiceId modelId=$modelId');
    final callable = FirebaseFunctions.instance.httpsCallable('generateTts');

    try {
      final response = await callable.call({
        'text': text,
        'language': language,
        'provider': provider.name,
        if (voiceId != null) 'voiceId': voiceId,
        if (modelId != null) 'modelId': modelId,
        if (speakingRate != null) 'speakingRate': speakingRate,
        if (pitch != null) 'pitch': pitch,
        if (elevenLabsSettings != null) 'elevenLabsSettings': elevenLabsSettings.toJson(),
      });
      AppLogger.i('[TTS][Repository] generateTts success');

      // 4. 결과 저장
      final String base64Audio = response.data['audioBase64'];
      final bytes = base64Decode(base64Audio);
      
      await file.writeAsBytes(bytes);
      final size = await file.length();
      AppLogger.i('[TTS][Repository] File saved to ${file.path} (size: $size bytes)');

      return file.path;
    } catch (e) {
      AppLogger.e('[TTS][Repository] Failed to generateTts provider=${provider.name}', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listVoices(String languageCode) async {
    final callable = FirebaseFunctions.instance.httpsCallable('listTtsVoices');
    final response = await callable.call({'languageCode': languageCode});
    
    final List<dynamic> voices = response.data['voices'];
    return voices.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listElevenLabsVoices() async {
    final callable = FirebaseFunctions.instance.httpsCallable('listElevenLabsVoices');
    final response = await callable.call();
    
    final List<dynamic> voices = response.data['voices'];
    return voices.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
