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
    previewText: '你好,很高兴认识你。',
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
