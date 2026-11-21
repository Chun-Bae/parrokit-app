import 'package:parrokit/features/content-studio/tts/data/data_sources/tts_remote_data_source.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_elevenlabs_models.dart';

class TtsVoiceCache {
  static final TtsVoiceCache _instance = TtsVoiceCache._internal();
  factory TtsVoiceCache() => _instance;
  TtsVoiceCache._internal();

  List<TtsElevenLabsVoice>? _elevenLabsVoices;
  List<TtsElevenLabsVoice>? get elevenLabsVoices => _elevenLabsVoices;

  /// 세션 캐시: 메모리에 데이터가 없으면 서버에서 받아오고, 있으면 메모리 값을 반환합니다.
  Future<List<TtsElevenLabsVoice>> fetchElevenLabsVoicesIfNeeded(
      TtsRemoteDataSource dataSource) async {
    if (_elevenLabsVoices != null) {
      return _elevenLabsVoices!;
    }

    try {
      final data = await dataSource.listElevenLabsVoices();
      _elevenLabsVoices =
          data.map((json) => TtsElevenLabsVoice.fromJson(json)).toList();
      return _elevenLabsVoices!;
    } catch (e) {
      // 에러 발생 시 메모리에 캐싱하지 않고 빈 리스트를 반환하거나 에러를 전파합니다.
      rethrow;
    }
  }

  // 나중에 Google TTS 등 다른 보이스 모델이 필요하면 여기에 동일하게 추가할 수 있습니다.
}
