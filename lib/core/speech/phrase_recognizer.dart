import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 따라 말하기용 음성 인식. 테스트에서 바꿔 끼울 수 있게 인터페이스로 둔다.
bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// 인식기가 주는 입력 크기를 0~1로 맞춘다.
/// iOS는 dBFS(조용하면 -50 아래, 말하면 -30~-10 근처)로, Android는 -2~10 안팎으로 온다.
double normalizeSoundLevel(double level, {required bool ios}) {
  if (level.isNaN) return 0;
  final value = ios ? (level + 50) / 40 : (level + 2) / 12;
  return value.clamp(0.0, 1.0);
}

abstract class PhraseRecognizer {
  /// 인식을 시작한다. 마이크 권한이나 인식 엔진이 없으면 false.
  Future<bool> start({
    required String localeId,
    required void Function(String text) onResult,
    required void Function(String? error) onDone,
    void Function(double level)? onLevel,
  });

  Future<void> stop();
}

class SpeechToTextRecognizer implements PhraseRecognizer {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  void Function(String? error)? _onDone;

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String text) onResult,
    required void Function(String? error) onDone,
    void Function(double level)? onLevel,
  }) async {
    _onDone = onDone;
    if (!_ready) {
      _ready = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[stt] status: $status');
          if (status == 'done' || status == 'notListening') _onDone?.call(null);
        },
        onError: (error) {
          debugPrint(
              '[stt] error: ${error.errorMsg} (permanent: ${error.permanent})');
          _onDone?.call(error.errorMsg);
        },
      );
    }
    debugPrint('[stt] initialize: $_ready, locale: $localeId');
    if (!_ready) return false;
    await _prepareAudioSession();
    await _speech.listen(
      onResult: (result) {
        debugPrint(
            '[stt] heard${result.finalResult ? ' (final)' : ''}: "${result.recognizedWords}"');
        onResult(result.recognizedWords);
      },
      onSoundLevelChange: (level) {
        _logLevel(level);
        onLevel?.call(normalizeSoundLevel(level, ios: _isIos));
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 4),
      ),
    );
    return true;
  }

  /// 앱의 배경 오디오(재생 전용) 설정이 마이크 입력을 막지 않도록 녹음 가능한 세션으로 맞춘다.
  Future<void> _prepareAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));
      debugPrint('[stt] audio session: playAndRecord');
    } catch (e) {
      debugPrint('[stt] audio session failed: $e');
    }
  }

  DateTime _lastLevelLog = DateTime.fromMillisecondsSinceEpoch(0);

  void _logLevel(double level) {
    final now = DateTime.now();
    if (now.difference(_lastLevelLog) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastLevelLog = now;
    debugPrint('[stt] level: ${level.toStringAsFixed(1)}');
  }

  @override
  Future<void> stop() => _speech.stop();
}
