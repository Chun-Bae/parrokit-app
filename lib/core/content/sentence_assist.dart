import 'package:parrokit/core/shared/utils/action_failed_text.dart';

/// 뜻·발음 자동 채우기와 한글 전사를 맡는 도우미.
///
/// 화면과 흐름은 이 인터페이스만 보고 만든다. 실제 구현은 서버 함수를 부르는
/// `CloudSentenceAssist`이고, 연결이 없는 곳에서는 [UnavailableSentenceAssist]를 쓴다.
abstract class SentenceAssist {
  /// 마지막 요청 뒤 서버가 알려 준 오늘 남은 횟수. 아직 모르면 null.
  int? get remainingToday;

  /// 서버가 알려 준 하루 한도. 아직 모르면 null.
  int? get dailyLimit;

  /// 모델을 부르지 않고 오늘 쓴 횟수만 서버에서 가져온다. 횟수를 쓰지 않는다.
  Future<void> refreshUsage();

  /// 원문에 맞는 뜻과 발음을 제안한다. 모르면 해당 값을 null로 돌려준다.
  Future<SentenceSuggestion> suggest({
    required String language,
    required String text,
  });

  /// 한글로 적은 소리를 [language]의 글자로 바꾼다. 바꿀 수 없으면 null.
  /// 예: 일본어 "곤니치와" → "こんにちは", 중국어 "니하오" → "你好"
  Future<String?> transliterate({
    required String language,
    required String hangul,
  });

  /// 낱말의 뜻과 예문을 함께 제안한다(5차 467).
  ///
  /// 전에는 낱말에도 문장용 [suggest]를 그대로 썼다. 그쪽은 쓰지도 않을
  /// 한글 발음까지 만들고 예문은 안 만들어서, 직접 더한 낱말에는 예문이
  /// 영영 없었다.
  ///
  /// [existingExamples]에 지금 들고 있는 예문을 넘기면 그것과 겹치지 않게
  /// 만든다. [count]는 만들 예문 수다(남은 자리보다 많이 오지 않는다).
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples,
    int count,
  });
}

/// 낱말 하나에 대한 제안.
class WordSuggestion {
  const WordSuggestion({
    this.translation,
    this.pronunciation,
    this.examples = const [],
  });

  final String? translation;

  /// 한글로 적은 소리(5차 468). 낱말 화면이 이것을 그대로 쓴다.
  final String? pronunciation;
  final List<SuggestedExample> examples;

  bool get isEmpty =>
      (translation == null || translation!.trim().isEmpty) &&
      (pronunciation == null || pronunciation!.trim().isEmpty) &&
      examples.isEmpty;
}

class SuggestedExample {
  const SuggestedExample({required this.text, this.translation = ''});

  final String text;
  final String translation;
}

class SentenceSuggestion {
  const SentenceSuggestion({this.translation, this.pronunciation});

  final String? translation;
  final String? pronunciation;

  bool get isEmpty =>
      (translation == null || translation!.trim().isEmpty) &&
      (pronunciation == null || pronunciation!.trim().isEmpty);
}

/// 오늘 횟수를 모두 썼을 때 던진다. 화면은 내일 다시 쓸 수 있다고 안내한다.
class SentenceAssistQuotaExceeded implements Exception {
  const SentenceAssistQuotaExceeded();

  @override
  String toString() => 'SentenceAssistQuotaExceeded';
}

/// 구현이 연결되지 않았을 때 던진다. 화면은 자동 기능을 끄고 직접 입력하게 안내한다.
class SentenceAssistUnavailable implements Exception {
  const SentenceAssistUnavailable([this.reason = comingSoonMessage]);
  final String reason;

  @override
  String toString() => 'SentenceAssistUnavailable: $reason';
}

/// 아직 구현이 없는 기본 도우미. 모든 요청을 "준비 중"으로 돌려준다.
class UnavailableSentenceAssist implements SentenceAssist {
  const UnavailableSentenceAssist();

  @override
  int? get remainingToday => null;

  @override
  int? get dailyLimit => null;

  @override
  Future<void> refreshUsage() async {}

  @override
  Future<SentenceSuggestion> suggest({
    required String language,
    required String text,
  }) =>
      Future.error(const SentenceAssistUnavailable());

  @override
  Future<String?> transliterate({
    required String language,
    required String hangul,
  }) =>
      Future.error(const SentenceAssistUnavailable());

  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) =>
      Future.error(const SentenceAssistUnavailable());
}

/// 키보드로 치기 어려워 한글 전사를 쓸 만한 언어.
bool supportsHangulTransliteration(String language) =>
    language == '일본어' || language == '중국어';
