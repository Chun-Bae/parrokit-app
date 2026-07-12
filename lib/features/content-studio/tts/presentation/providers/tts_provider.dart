import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

import '../../data/data_sources/tts_remote_data_source.dart';
import '../../data/repositories/tts_generation_repository_impl.dart';
import '../../domain/models/tts_language.dart';
import '../../domain/repositories/tts_generation_repository.dart';
import '../../domain/usecases/generate_tts_usecase.dart';

class TtsProvider extends ChangeNotifier {
  late final GenerateTtsUseCase _useCase;
  final UserProvider userProvider;

  TtsProvider({required this.userProvider, GenerateTtsUseCase? useCase}) {
    _useCase = useCase ??
        GenerateTtsUseCase(
          TtsGenerationRepositoryImpl(TtsRemoteDataSource()),
        );
  }

  String _text = '';
  String get text => _text;

  String _voiceId = '';
  String get voiceId => _voiceId;

  String _language = 'ko-KR';
  String get language => _language;

  TtsProviderType _providerType = TtsProviderType.google;
  TtsProviderType get providerType => _providerType;

  String? _modelId;
  String? get modelId => _modelId;

  double _speakingRate = 1.0;
  double get speakingRate => _speakingRate;

  double _pitch = 0.0;
  double get pitch => _pitch;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  double _elevenLabsStability = 0.50;
  double get elevenLabsStability => _elevenLabsStability;

  double _elevenLabsSimilarityBoost = 0.75;
  double get elevenLabsSimilarityBoost => _elevenLabsSimilarityBoost;

  double _elevenLabsStyle = 0.0;
  double get elevenLabsStyle => _elevenLabsStyle;

  bool _elevenLabsUseSpeakerBoost = true;
  bool get elevenLabsUseSpeakerBoost => _elevenLabsUseSpeakerBoost;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _generatedFilePath;
  String? get generatedFilePath => _generatedFilePath;

  List<Map<String, dynamic>> _availableVoices = [];
  List<Map<String, dynamic>> get availableVoices => _availableVoices;

  bool _isLoadingVoices = false;
  bool get isLoadingVoices => _isLoadingVoices;

  /// 현재 스크립트 기준 예상 소모 패롯.
  int get estimatedCost => _calculateCoinCost(_text.length);

  void updateText(String newText) {
    if (newText.length <= 240) {
      _text = newText;
      notifyListeners();
    }
  }

  void updateVoiceId(String newVoiceId) {
    _voiceId = newVoiceId;
    notifyListeners();
  }

  void updateLanguage(String newLanguage) {
    _language = newLanguage;
    notifyListeners();
  }

  void updateProviderType(TtsProviderType newProviderType) {
    _providerType = newProviderType;
    notifyListeners();
  }

  void updateModelId(String? newModelId) {
    _modelId = newModelId;
    notifyListeners();
  }

  void updateSpeakingRate(double rate) {
    _speakingRate = rate;
    notifyListeners();
  }

  void updatePitch(double newPitch) {
    _pitch = newPitch;
    notifyListeners();
  }

  void updateElevenLabsStability(double value) {
    _elevenLabsStability = value;
    notifyListeners();
  }

  void updateElevenLabsSimilarityBoost(double value) {
    _elevenLabsSimilarityBoost = value;
    notifyListeners();
  }

  void updateElevenLabsStyle(double value) {
    _elevenLabsStyle = value;
    notifyListeners();
  }

  void updateElevenLabsUseSpeakerBoost(bool value) {
    _elevenLabsUseSpeakerBoost = value;
    notifyListeners();
  }

  Future<void> fetchAvailableVoices() async {
    if (_providerType != TtsProviderType.google) return;
    
    _isLoadingVoices = true;
    notifyListeners();

    try {
      final voices = await _useCase.repository.listVoices(_language);
      _availableVoices = voices;
      
      // 언어가 바뀌었는데 현재 선택된 voiceId가 새 언어 목록에 없다면 초기화
      if (_voiceId.isNotEmpty) {
        final exists = voices.any((v) => v['name'] == _voiceId);
        if (!exists) {
          _voiceId = '';
        }
      }
    } catch (e) {
      AppLogger.e('[TTS][Provider] Failed to load voices', error: e);
      _availableVoices = [];
    } finally {
      _isLoadingVoices = false;
      notifyListeners();
    }
  }

  Future<void> generateTts() async {
    if (_text.trim().isEmpty) return;

    final cost = _calculateCoinCost(_text.length);
    if (userProvider.coins < cost) {
      showToast('패롯이 부족합니다. (필요 $cost / 보유 ${userProvider.coins})');
      return;
    }

    AppLogger.i('[TTS][Provider] Starting generateTts provider=${_providerType.name} text_length=${_text.length}');
    _isGenerating = true;
    _errorMessage = null;
    _generatedFilePath = null;
    notifyListeners();

    try {
      final path = await _useCase.call(
        text: _text,
        language: _language,
        provider: _providerType,
        voiceId: _voiceId.isEmpty ? null : _voiceId,
        modelId: _modelId,
        speakingRate: _speakingRate,
        pitch: _pitch,
        elevenLabsSettings: _providerType == TtsProviderType.elevenlabs
            ? ElevenLabsVoiceSettings(
                stability: _elevenLabsStability,
                similarityBoost: _elevenLabsSimilarityBoost,
                style: _elevenLabsStyle,
                useSpeakerBoost: _elevenLabsUseSpeakerBoost,
              )
            : null,
      );
      AppLogger.i('[TTS][Provider] generateTts success path_length=${path.length}');
      _generatedFilePath = path;

      if (cost > 0) {
        userProvider.addCoins(-cost);
        showToast('음성 생성 완료! ($cost패롯 소모)');
      }
    } catch (e) {
      AppLogger.e('[TTS][Provider] generateTts failed provider=${_providerType.name}', error: e);
      _errorMessage = e.toString();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
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
      AppLogger.e('[TTS][Provider] previewGoogleVoice failed voiceId=$voiceId', error: e);
      return null;
    }
  }

  int _calculateCoinCost(int textLength) {
    if (textLength <= 0) return 0;
    return ((textLength + 49) ~/ 50).clamp(1, 1 << 30);
  }
}
