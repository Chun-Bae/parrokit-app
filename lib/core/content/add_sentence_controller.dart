import 'package:flutter/widgets.dart';

import 'sentence_assist.dart';

enum AssistStatus {
  /// 아무것도 하지 않는 상태.
  idle,
  loading,

  /// 도우미가 연결되지 않아 자동 기능을 껐다.
  unavailable,

  /// 오늘 쓸 수 있는 횟수를 모두 썼다.
  quotaExceeded,

  /// 한 번 실패했지만 다시 시도할 수 있다.
  failed,
}

/// 오늘 사용 횟수를 읽는 상태.
enum UsageStatus {
  loading,
  ready,

  /// 로그인하지 않았거나 서버에서 못 읽었다.
  unknown,
}

/// 저장할 문장 한 개의 입력값.
class AddedSentence {
  const AddedSentence({
    required this.language,
    required this.text,
    required this.translation,
    this.pronunciation = '',
  });

  final String language;
  final String text;
  final String translation;
  final String pronunciation;
}

/// 문장 추가 화면의 입력과 자동 채우기, 한글 전사 흐름.
///
/// - 하루 횟수가 적어서 입력만으로는 요청하지 않고, "채우기" 버튼([fill])을 눌렀을 때만 요청한다.
/// - 사용자가 직접 쓴 칸은 덮어쓰지 않는다. 비어 있거나 자동으로 채운 값 그대로인 칸만 갱신한다.
/// - 늦게 도착한 오래된 응답은 버린다.
/// - 도우미가 연결되지 않았거나 오늘 횟수를 다 썼으면 직접 입력으로 돌아간다.
class AddSentenceController extends ChangeNotifier {
  AddSentenceController({
    required this.language,
    required this.assist,
  });

  /// 문장을 추가할 언어. 화면에서 고르면 바뀐다.
  String language;
  final SentenceAssist assist;

  final text = TextEditingController();
  final translation = TextEditingController();
  final pronunciation = TextEditingController();

  /// 한글 전사 입력칸. 일본어·중국어에서만 쓴다.
  final hangul = TextEditingController();

  /// 오늘 사용 횟수를 읽는 중인지, 읽었는지, 못 읽었는지.
  UsageStatus usageStatus = UsageStatus.loading;

  AssistStatus fillStatus = AssistStatus.idle;
  AssistStatus transliterateStatus = AssistStatus.idle;

  String _lastAutoTranslation = '';
  String _lastAutoPronunciation = '';
  int _fillToken = 0;
  bool _disposed = false;

  bool get canTransliterate => supportsHangulTransliteration(language);

  /// 서버가 알려 준 오늘 남은 횟수. 아직 모르면 null.
  int? get remainingToday => assist.remainingToday;

  /// 서버가 알려 준 하루 한도. 아직 모르면 null.
  int? get dailyLimit => assist.dailyLimit;

  /// 오늘 쓴 횟수. 한도나 남은 횟수를 아직 모르면 null.
  int? get usedToday {
    final limit = dailyLimit;
    final remaining = remainingToday;
    if (limit == null || remaining == null) return null;
    return (limit - remaining).clamp(0, limit);
  }

  /// 화면을 열 때 한 번 불러 사용 횟수를 보여 준다. 모델을 부르지 않아 횟수를 쓰지 않는다.
  Future<void> loadUsage() async {
    usageStatus = UsageStatus.loading;
    notifyListeners();
    await assist.refreshUsage();
    if (_disposed) return;
    usageStatus = usedToday == null ? UsageStatus.unknown : UsageStatus.ready;
    notifyListeners();
  }

  /// 원문과 뜻이 있어야 저장할 수 있다. 발음은 선택이다.
  bool get canSave =>
      text.text.trim().isNotEmpty && translation.text.trim().isNotEmpty;

  /// 언어를 바꾼다. 원문과 뜻은 그대로 두고, 아직 오지 않은 이전 언어의 응답은 버린다.
  void setLanguage(String next) {
    if (next == language) return;
    language = next;
    _fillToken++;
    fillStatus = AssistStatus.idle;
    transliterateStatus = AssistStatus.idle;
    notifyListeners();
  }

  AddedSentence? build() => canSave
      ? AddedSentence(
          language: language,
          text: text.text.trim(),
          translation: translation.text.trim(),
          pronunciation: pronunciation.text.trim(),
        )
      : null;

  /// 지금 원문으로 뜻과 발음을 요청한다. 화면의 "뜻·발음 채우기" 버튼이 이걸 부른다.
  Future<void> fill() async {
    final source = text.text.trim();
    if (source.isEmpty || _disposed) return;
    final token = ++_fillToken;
    fillStatus = AssistStatus.loading;
    notifyListeners();
    try {
      final suggestion = await assist.suggest(language: language, text: source);
      if (_disposed || token != _fillToken) return;
      _apply(suggestion);
      fillStatus = AssistStatus.idle;
    } on SentenceAssistQuotaExceeded {
      if (_disposed || token != _fillToken) return;
      fillStatus = AssistStatus.quotaExceeded;
    } on SentenceAssistUnavailable {
      if (_disposed || token != _fillToken) return;
      fillStatus = AssistStatus.unavailable;
    } catch (_) {
      if (_disposed || token != _fillToken) return;
      fillStatus = AssistStatus.failed;
    }
    notifyListeners();
  }

  void _apply(SentenceSuggestion suggestion) {
    final nextTranslation = suggestion.translation?.trim();
    if (nextTranslation != null &&
        nextTranslation.isNotEmpty &&
        _isOverwritable(translation, _lastAutoTranslation)) {
      translation.text = nextTranslation;
      _lastAutoTranslation = nextTranslation;
    }
    final nextPronunciation = suggestion.pronunciation?.trim();
    if (nextPronunciation != null &&
        nextPronunciation.isNotEmpty &&
        _isOverwritable(pronunciation, _lastAutoPronunciation)) {
      pronunciation.text = nextPronunciation;
      _lastAutoPronunciation = nextPronunciation;
    }
  }

  /// 비어 있거나 자동으로 채운 값 그대로면 새 제안으로 바꿔도 된다.
  bool _isOverwritable(TextEditingController field, String lastAuto) =>
      field.text.trim().isEmpty || field.text.trim() == lastAuto;

  /// 한글로 적은 소리를 대상 언어 글자로 바꿔 원문칸에 넣는다.
  Future<void> transliterate() async {
    final source = hangul.text.trim();
    if (!canTransliterate || source.isEmpty || _disposed) return;
    transliterateStatus = AssistStatus.loading;
    notifyListeners();
    try {
      final converted =
          await assist.transliterate(language: language, hangul: source);
      if (_disposed) return;
      if (converted == null || converted.trim().isEmpty) {
        transliterateStatus = AssistStatus.failed;
      } else {
        text.text = converted.trim();
        transliterateStatus = AssistStatus.idle;
      }
    } on SentenceAssistQuotaExceeded {
      if (_disposed) return;
      transliterateStatus = AssistStatus.quotaExceeded;
    } on SentenceAssistUnavailable {
      if (_disposed) return;
      transliterateStatus = AssistStatus.unavailable;
    } catch (_) {
      if (_disposed) return;
      transliterateStatus = AssistStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    text.dispose();
    translation.dispose();
    pronunciation.dispose();
    hangul.dispose();
    super.dispose();
  }
}
