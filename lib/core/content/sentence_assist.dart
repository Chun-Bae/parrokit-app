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
  const SentenceAssistUnavailable([this.reason = '아직 준비 중이에요']);
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
}

/// 키보드로 치기 어려워 한글 전사를 쓸 만한 언어.
bool supportsHangulTransliteration(String language) =>
    language == '일본어' || language == '중국어';
