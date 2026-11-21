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

  /// 오늘 더 만들 수 있는 예문 수. 뜻·발음 채우기와 다른 한도다. 모르면 null.
  int? get examplesRemainingToday;

  /// 하루에 만들 수 있는 예문 수. 모르면 null.
  int? get exampleDailyLimit;

  /// 이 단계에서 낱말 하나가 들 수 있는 예문 수. 모르면 null.
  int? get maxExamplesPerWord;

  /// 패롯으로 사 둔 예문 몫(5차 532). 하루 한도와 다른 주머니라 사라지지
  /// 않는다. [examplesRemainingToday]에는 이 수가 이미 더해져 있다.
  int? get exampleCredits;

  /// 패롯으로 사 둔 뜻·발음 채우기 몫(5차 535). [remainingToday]에 이미
  /// 더해져 있다.
  int? get assistCredits;

  /// 모델을 부르지 않고 오늘 쓴 횟수만 서버에서 가져온다. 횟수를 쓰지 않는다.
  Future<void> refreshUsage();

  /// 원문에 맞는 뜻과 발음을 제안한다. 모르면 해당 값을 null로 돌려준다.
  Future<SentenceSuggestion> suggest({
    required String language,
    required String text,
  });

  /// 적혀 있는 칸으로 비어 있는 칸을 채운다(5차 545, 사용자 요청).
  ///
  /// 전에는 길이 셋이었다 - 원문으로 뜻·발음, 발음으로 원문, 뜻으로 원문.
  /// 사용자가 보기에는 "빈 칸을 채운다" 하나인데 각각 하루 횟수를 썼다.
  /// 한 번에 끝낸다. 셋 가운데 적어도 하나는 적혀 있어야 한다.
  Future<SentenceComplete> complete({
    required String language,
    String text,
    String translation,
    String pronunciation,
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

/// 빈 칸을 채운 결과(5차 545). 적혀 있던 칸도 그대로 담겨 온다.
class SentenceComplete {
  const SentenceComplete({
    this.text,
    this.translation,
    this.pronunciation,
  });

  final String? text;
  final String? translation;
  final String? pronunciation;
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
  const SentenceAssistQuotaExceeded({this.examples = false});

  /// 다 쓴 것이 예문 한도인지(5차 517). 서버는 두 한도 모두
  /// `resource-exhausted`로 돌려주므로 어느 쪽인지 여기에 실어 나른다.
  /// 뜻·발음 채우기 한도와 예문 생성 한도는 서로 다른 축이다.
  final bool examples;

  @override
  String toString() => 'SentenceAssistQuotaExceeded(examples: $examples)';
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
  int? get examplesRemainingToday => null;

  @override
  int? get exampleDailyLimit => null;

  @override
  int? get maxExamplesPerWord => null;

  @override
  int? get exampleCredits => null;

  @override
  int? get assistCredits => null;

  @override
  Future<void> refreshUsage() async {}

  @override
  Future<SentenceSuggestion> suggest({
    required String language,
    required String text,
  }) =>
      Future.error(const SentenceAssistUnavailable());

  @override
  Future<SentenceComplete> complete({
    required String language,
    String text = '',
    String translation = '',
    String pronunciation = '',
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

/// 오늘 만들 수 있는 예문을 다 썼을 때. 뜻·발음 채우기 한도와 다른 말이다.
const String exampleQuotaExhaustedText =
    '오늘 만들 수 있는 예문을 다 썼어요. 내일 다시 만들 수 있어요.';

/// 이 낱말에 더 만들어 줄 자리가 없을 때. 직접 적는 것은 [examplesMaxCount]까지
/// 되므로 '넣을 수 있어요'가 아니라 '만들어 줘요'라고 적는다(5차 506).
String exampleFillCapText(int cap) => '지금 단계에서는 예문을 낱말마다 $cap개까지 만들어 줘요.';

