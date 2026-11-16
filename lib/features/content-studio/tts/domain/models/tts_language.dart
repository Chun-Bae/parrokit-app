import 'package:parrokit/core/content/learning_languages.dart';

class TtsLanguage {
  final String mlKitCode;
  final String ttsCode;
  final String displayName;

  /// 보이스 미리듣기에 사용하는 짧은 예문.
  final String previewText;

  const TtsLanguage({
    required this.mlKitCode,
    required this.ttsCode,
    required this.displayName,
    required this.previewText,
  });
}

const List<TtsLanguage> supportedTtsLanguages = [
  TtsLanguage(
    mlKitCode: 'ko',
    ttsCode: 'ko-KR',
    displayName: '한국어 (ko-KR)',
    previewText: '안녕하세요, 만나서 반가워요.',
  ),
  TtsLanguage(
    mlKitCode: 'en',
    ttsCode: 'en-US',
    displayName: '영어 (en-US)',
    previewText: 'Hello, nice to meet you.',
  ),
  TtsLanguage(
    mlKitCode: 'ja',
    ttsCode: 'ja-JP',
    displayName: '일본어 (ja-JP)',
    previewText: 'こんにちは、はじめまして。',
  ),
  TtsLanguage(
    mlKitCode: 'zh',
    ttsCode: 'cmn-CN',
    displayName: '중국어 (cmn-CN)',
    previewText: '你好，很高兴认识你。',
  ),
  TtsLanguage(
    mlKitCode: 'es',
    ttsCode: 'es-ES',
    displayName: '스페인어 (es-ES)',
    previewText: 'Hola, encantado de conocerte.',
  ),
  TtsLanguage(
    mlKitCode: 'fr',
    ttsCode: 'fr-FR',
    displayName: '프랑스어 (fr-FR)',
    previewText: 'Bonjour, ravi de vous rencontrer.',
  ),
  TtsLanguage(
    mlKitCode: 'de',
    ttsCode: 'de-DE',
    displayName: '독일어 (de-DE)',
    previewText: 'Hallo, schön dich kennenzulernen.',
  ),
];

TtsLanguage? getLanguageByMlKitCode(String code) {
  try {
    return supportedTtsLanguages.firstWhere((lang) => lang.mlKitCode == code);
  } catch (e) {
    return null;
  }
}

TtsLanguage getLanguageByTtsCode(String code) {
  try {
    return supportedTtsLanguages.firstWhere((lang) => lang.ttsCode == code);
  } catch (e) {
    return supportedTtsLanguages.first; // 기본값 한국어
  }
}

/// 음성 만들기를 열었을 때 처음 고를 언어(5차 360).
///
/// 전에는 한국어였다. 이 앱에서 음성을 만드는 까닭은 대개 배우는 말(영어 등)을
/// 들으려는 것이라, 배우는 말 목록의 첫 언어로 맞춘다. 짝이 없으면 한국어.
String get defaultTtsLanguageCode {
  final learning = availableLearningLanguages.first.code;
  for (final language in supportedTtsLanguages) {
    if (language.mlKitCode == learning) return language.ttsCode;
  }
  return supportedTtsLanguages.first.ttsCode;
}
