import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

import '../../data/data_sources/tts_remote_data_source.dart';
import '../../data/repositories/tts_generation_repository_impl.dart';
import '../../domain/models/tts_elevenlabs_models.dart';
import '../../domain/models/tts_gemini_models.dart';
import '../../domain/models/tts_google_models.dart';
import '../../domain/models/tts_language.dart';
import '../../domain/repositories/tts_generation_repository.dart';
import '../../domain/usecases/generate_tts_usecase.dart';
import 'tts_provider_settings.dart';

class TtsProvider extends ChangeNotifier {
  late final GenerateTtsUseCase _useCase;
  final UserProvider userProvider;

  TtsProvider({required this.userProvider, GenerateTtsUseCase? useCase}) {
    _useCase = useCase ??
        GenerateTtsUseCase(
          TtsGenerationRepositoryImpl(TtsRemoteDataSource()),
        );
  }

  // provider별 설정. 서로 다른 필드만 갖고 있어 값이 새어 들어갈 수 없다.
  final GoogleTtsSettings _google = GoogleTtsSettings();
  final ElevenLabsTtsSettings _elevenLabs = ElevenLabsTtsSettings();
  final GeminiTtsSettings _gemini = GeminiTtsSettings();

  String _text = '';
  String get text => _text;

  String get voiceId => switch (_providerType) {
        TtsProviderType.google => _google.voiceId,
        TtsProviderType.elevenlabs => _elevenLabs.voiceId,
        TtsProviderType.gemini => _gemini.voiceId,
      };

  String _language = 'ko-KR';
  String get language => _language;

  TtsProviderType _providerType = TtsProviderType.google;
  TtsProviderType get providerType => _providerType;

  String? get modelId => switch (_providerType) {
        TtsProviderType.google => null,
        TtsProviderType.elevenlabs => _elevenLabs.modelId,
        TtsProviderType.gemini => _gemini.modelId,
      };

  double get speakingRate => _google.speakingRate;

  double get pitch => _google.pitch;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  double get elevenLabsStability => _elevenLabs.stability;

  double get elevenLabsSimilarityBoost => _elevenLabs.similarityBoost;

  double get elevenLabsStyle => _elevenLabs.style;

  bool get elevenLabsUseSpeakerBoost => _elevenLabs.useSpeakerBoost;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _generatedFilePath;
  String? get generatedFilePath => _generatedFilePath;

  List<Map<String, dynamic>> _availableVoices = [];
  List<Map<String, dynamic>> get availableVoices => _availableVoices;

  bool _isLoadingVoices = false;
  bool get isLoadingVoices => _isLoadingVoices;

  /// 보이스 목록을 불러오지 못했는지. 전에는 실패해도 빈 목록이 돼
  /// '선택 (기본값)'으로 보여, 목록이 원래 없는 것인지 못 가져온 것인지
  /// 알 수 없었다. 네트워크가 느리면 '목록 불러오는 중...'에서 끝나지 않았다
  /// (5차).
  bool _voicesFailed = false;
  bool get voicesFailed => _voicesFailed;

  /// 이보다 오래 걸리면 못 가져온 것으로 본다.
  static const voicesTimeout = Duration(seconds: 15);

  /// 현재 스크립트 기준 예상 소모 패롯.
  int get estimatedCost => _calculateCoinCost(_text.length);

  void updateText(String newText) {
    if (newText.length <= 240) {
      _text = newText;
      notifyListeners();
    }
  }

  void updateVoiceId(String newVoiceId) {
    switch (_providerType) {
      case TtsProviderType.google:
        _google.voiceId = newVoiceId;
      case TtsProviderType.elevenlabs:
        _elevenLabs.voiceId = newVoiceId;
      case TtsProviderType.gemini:
        _gemini.voiceId = newVoiceId;
    }
    notifyListeners();
  }

  void updateLanguage(String newLanguage) {
    _language = newLanguage;
    notifyListeners();
  }

  void updateProviderType(TtsProviderType newProviderType) {
    if (newProviderType == _providerType) return;
    _providerType = newProviderType;
    notifyListeners();
  }

  void updateModelId(String? newModelId) {
    switch (_providerType) {
      case TtsProviderType.google:
        break; // Google TTS는 modelId 개념이 없음
      case TtsProviderType.elevenlabs:
        _elevenLabs.modelId = newModelId;
      case TtsProviderType.gemini:
        _gemini.modelId = newModelId;
    }
    notifyListeners();
  }

  void updateSpeakingRate(double rate) {
    _google.speakingRate = rate;
    notifyListeners();
  }

  void updatePitch(double newPitch) {
    _google.pitch = newPitch;
    notifyListeners();
  }

  void updateElevenLabsStability(double value) {
    _elevenLabs.stability = value;
    notifyListeners();
  }

  void updateElevenLabsSimilarityBoost(double value) {
    _elevenLabs.similarityBoost = value;
    notifyListeners();
  }

  void updateElevenLabsStyle(double value) {
    _elevenLabs.style = value;
    notifyListeners();
  }

  void updateElevenLabsUseSpeakerBoost(bool value) {
    _elevenLabs.useSpeakerBoost = value;
    notifyListeners();
  }

  /// 보이스 목록 조회 요청 번호. 언어를 바꾸면 올라간다.
  int _voicesRequestId = 0;

  Future<void> fetchAvailableVoices() async {
    if (_providerType != TtsProviderType.google) return;

    final requestId = ++_voicesRequestId;
    final requestedLanguage = _language;

    _isLoadingVoices = true;
    _voicesFailed = false;
    notifyListeners();

    try {
      final voices = await _useCase.repository
          .listVoices(requestedLanguage)
          .timeout(voicesTimeout);

      // 기다리는 동안 언어가 또 바뀌었으면 이 목록은 버린다. 언어 고르기
      // 시트는 updateLanguage 직후 이 함수를 await 없이 부르므로, 빠르게
      // 두 번 고르면 늦게 끝난 옛 조회가 이긴다. 그러면 다른 언어의 보이스
      // 목록이 뜰 뿐 아니라, 아래 "목록에 없으면 초기화"가 멀쩡히 고른
      // 보이스를 지워 버린다.
      if (requestId != _voicesRequestId) return;

      _availableVoices = voices;

      // 언어가 바뀌었는데 현재 선택된 voiceId가 새 언어 목록에 없다면 초기화
      if (_google.voiceId.isNotEmpty) {
        final exists = voices.any((v) => v['name'] == _google.voiceId);
        if (!exists) {
          _google.voiceId = '';
        }
      }
    } catch (e) {
      AppLogger.e('[TTS][Provider] Failed to load voices', error: e);
      if (requestId != _voicesRequestId) return;
      _availableVoices = [];
      _voicesFailed = true;
    } finally {
      if (requestId == _voicesRequestId) {
        _isLoadingVoices = false;
        notifyListeners();
      }
    }
  }

  Future<void> generateTts() async {
    if (_text.trim().isEmpty) return;

    final cost = _calculateCoinCost(_text.length);
    if (userProvider.coins < cost) {
      showToast('패롯이 부족합니다. (필요 $cost / 보유 ${userProvider.coins})');
      return;
    }

    AppLogger.i(
        '[TTS][Provider] Starting generateTts provider=${_providerType.name} text_length=${_text.length}');
    _isGenerating = true;
    _errorMessage = null;
    _generatedFilePath = null;
    notifyListeners();

    try {
      var charged = 0;
      final path = await _useCase.call(
        serverCharge: true,
        onCharged: (value) => charged = value,
        text: _text,
        language: _language,
        provider: _providerType,
        voiceId: voiceId.isEmpty ? null : voiceId,
        modelId: modelId,
        speakingRate: _google.speakingRate,
        pitch: _google.pitch,
        elevenLabsSettings: _providerType == TtsProviderType.elevenlabs
            ? ElevenLabsVoiceSettings(
                stability: _elevenLabs.stability,
                similarityBoost: _elevenLabs.similarityBoost,
                style: _elevenLabs.style,
                useSpeakerBoost: _elevenLabs.useSpeakerBoost,
              )
            : null,
      );
      AppLogger.i(
          '[TTS][Provider] generateTts success path_length=${path.length}');
      _generatedFilePath = path;

      // 패롯은 서버(generateTts)가 만들기 전에 깎고, 실패하면 돌려준다.
      // 잔액은 사용자 문서 구독으로 화면에 반영된다. 기기에 캐시된 음성을
      // 다시 꺼낸 경우는 서버를 부르지 않아 깎이지 않는다.
      showToast(charged > 0 ? '음성 생성 완료! ($charged패롯 소모)' : '음성 생성 완료!');
    } catch (e) {
      AppLogger.e(
          '[TTS][Provider] generateTts failed provider=${_providerType.name}',
          error: e);
      _errorMessage = e.toString();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 이 Provider는 콘텐츠 제작 화면에서 만들어지고 화면을 떠나면 dispose된다.
  /// 생성·조회가 도는 중에 떠나면 dispose 뒤에 notifyListeners가 불린다.
  /// debug 빌드에서는 ChangeNotifier의 assert에 걸려 빨간 화면이 뜨고,
  /// release에서는 조용히 넘어간다. 개발 중에만 터지는 종류라 더 늦게 보인다.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void clearGeneratedAudio() {
    _generatedFilePath = null;
    notifyListeners();
  }

  /// 보이스 선택 화면에서 짧은 예문으로 미리듣기 오디오를 생성합니다.
  /// 실패 시 null을 반환하며, 메인 생성 상태(`generatedFilePath` 등)는 건드리지 않습니다.
  Future<String?> previewGoogleVoice(String voiceId) async {
    try {
      return await _useCase.repository.generateTts(
        text: getLanguageByTtsCode(_language).previewText,
        language: _language,
        provider: TtsProviderType.google,
        voiceId: voiceId,
      );
    } catch (e) {
      AppLogger.e('[TTS][Provider] previewGoogleVoice failed voiceId=$voiceId',
          error: e);
      return null;
    }
  }

  int _calculateCoinCost(int textLength) {
    if (textLength <= 0) return 0;
    final charsPerParrot = _currentCharsPerParrot();
    return ((textLength + charsPerParrot - 1) ~/ charsPerParrot)
        .clamp(1, 1 << 30);
  }

  /// 현재 선택된 엔진/모델 기준 1패롯이 커버하는 글자 수.
  int _currentCharsPerParrot() {
    switch (_providerType) {
      case TtsProviderType.google:
        return googleTtsCharsPerParrot;
      case TtsProviderType.elevenlabs:
        final id = _elevenLabs.modelId ?? 'eleven_multilingual_v2';
        return elevenLabsModels
            .firstWhere((m) => m.id == id, orElse: () => elevenLabsModels.first)
            .charsPerParrot;
      case TtsProviderType.gemini:
        final id = _gemini.modelId ?? defaultGeminiTtsModelId;
        return geminiModels
            .firstWhere((m) => m.id == id, orElse: () => geminiModels.first)
            .charsPerParrot;
    }
  }
}
