import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
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
/// 문장 입력 한도(5차, 사용자 요청: 80 → 200).
///
/// 80자는 대사 한 줄에는 맞지만, 조금만 긴 문장을 넣으려면 끊어야 했다.
const int sentenceMaxLength = 200;

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

  /// 오늘 사용 횟수를 읽는 중인지, 읽었는지, 못 읽었는지.
  UsageStatus usageStatus = UsageStatus.loading;

  /// 빈 칸 채우기 하나로 합쳤다(5차 545). 전에는 길마다 상태가 따로 있었다.
  AssistStatus fillStatus = AssistStatus.idle;

  String _lastAutoTranslation = '';
  String _lastAutoPronunciation = '';

  /// 자동으로 채운 원문. 손으로 적은 원문을 덮지 않으려고 기억해 둔다.
  String _lastAutoText = '';
  int _fillToken = 0;
  bool _disposed = false;

  /// 서버가 알려 준 오늘 남은 횟수. 아직 모르면 null.
  int? get remainingToday => assist.remainingToday;

  /// 서버가 알려 준 하루 한도. 아직 모르면 null.
  int? get dailyLimit => assist.dailyLimit;

  /// 패롯으로 사 둔 뜻·발음 몫(5차 546). 하루 한도와 다른 주머니다.
  int? get assistCredits => assist.assistCredits;

  /// 오늘 쓴 횟수. 한도나 남은 횟수를 아직 모르면 null.
  int? get usedToday => assistUsedToday(
        limit: dailyLimit,
        remaining: remainingToday,
        credits: assist.assistCredits ?? 0,
      );

  /// 오늘 횟수를 다 썼나(5차 478).
  ///
  /// 아직 못 읽었으면 false다. 모르는데 막아 두면 쓸 수 있는 사람도
  /// 못 쓴다.
  bool get exhausted => assistExhausted(
        used: usedToday,
        limit: dailyLimit,
        credits: assist.assistCredits ?? 0,
      );

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
  bool get canSave => blockedReason == null;

  /// 아직 추가할 수 없는 까닭. 추가할 수 있으면 null.
  /// 커뮤니티 글쓰기와 같은 결로 적는다(5차).
  String? get blockedReason {
    if (text.text.trim().isEmpty) return sentenceNeededMessage;
    if (translation.text.trim().isEmpty) return '뜻을 적어 주세요.';
    return null;
  }

  /// 언어를 바꾼다. 원문과 뜻은 그대로 두고, 아직 오지 않은 이전 언어의 응답은 버린다.
  void setLanguage(String next) {
    if (next == language) return;
    language = next;
    _fillToken++;
    fillStatus = AssistStatus.idle;
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

  /// 채우기가 바꿀 수 있는 칸이 남았는지(5차 526).
  ///
  /// 뜻과 발음을 손으로 다 적어 두면 [_apply]가 아무것도 덮어쓰지 않는다.
  /// 그런데도 단추가 열려 있어서, 눌러 보면 서버를 부르고 하루 횟수만 한 번
  /// 줄고 화면은 그대로였다(기기에서 그렇게 한 번을 버렸다).
  ///
  /// 자동으로 채운 값만 있으면 '다시 받기'로 쓸 수 있으니 그대로 열어 둔다.
  bool get hasFillRoom =>
      _isOverwritable(text, _lastAutoText) ||
      _isOverwritable(translation, _lastAutoTranslation) ||
      _isOverwritable(pronunciation, _lastAutoPronunciation);

  /// 채울 재료가 있는지. 셋 가운데 하나라도 적혀 있어야 한다(5차 545).
  bool get hasFillSource =>
      text.text.trim().isNotEmpty ||
      translation.text.trim().isNotEmpty ||
      pronunciation.text.trim().isNotEmpty;

  /// 사용자가 손으로 적어 둔 칸 수. 자동으로 채운 값은 치지 않는다.
  ///
  /// 자동 값은 재료가 아니라 우리가 내놓은 것이다. 그것까지 세면 한 번
  /// 채우고 나서 '다시 받기'를 할 수 없다.
  int get typedFieldCount => [
        _isOverwritable(text, _lastAutoText),
        _isOverwritable(translation, _lastAutoTranslation),
        _isOverwritable(pronunciation, _lastAutoPronunciation),
      ].where((overwritable) => !overwritable).length;

  /// 재료가 둘 이상이라 기준이 애매한지(5차 553, 사용자 결정).
  ///
  /// 두 칸을 적어 두면 셋 다 기준이 흔들린다. (뜻, 발음)으로 원문을 만들 때
  /// 둘이 어긋나면 어느 쪽에도 맞출 수 없고, (원문, 뜻)이나 (원문, 발음)도
  /// 어긋난 채로 두면 나머지 한 칸을 무엇에 맞춰야 하는지 알 수 없다.
  /// 모델은 아무 말 없이 한쪽을 골라 버린다.
  ///
  /// 그래서 손으로 적은 칸이 하나일 때만 만든다.
  bool get hasRivalSources => typedFieldCount >= 2;

  /// 적혀 있는 칸으로 빈 칸을 채운다(5차 545, 사용자 요청).
  ///
  /// 전에는 단추가 셋이었다 - 원문으로 뜻·발음, 뜻으로 원문, 발음으로 원문.
  /// 뜻만 적고 다 채우려면 두 번 눌러 하루 횟수를 두 번 썼다. 한 번에
  /// 끝낸다. 손으로 적어 둔 칸은 [_apply]가 덮지 않는다.
  Future<void> fill() async {
    if (_disposed || !hasFillSource || !hasFillRoom) return;
    if (hasRivalSources) return;
    final token = ++_fillToken;
    fillStatus = AssistStatus.loading;
    notifyListeners();
    try {
      final filled = await assist.complete(
        language: language,
        text: text.text.trim(),
        translation: translation.text.trim(),
        pronunciation: pronunciation.text.trim(),
      );
      if (_disposed || token != _fillToken) return;
      _apply(filled);
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

  void _apply(SentenceComplete filled) {
    final nextText = filled.text?.trim();
    if (nextText != null &&
        nextText.isNotEmpty &&
        _isOverwritable(text, _lastAutoText)) {
      text.text = nextText;
      _lastAutoText = nextText;
    }
    final nextTranslation = filled.translation?.trim();
    if (nextTranslation != null &&
        nextTranslation.isNotEmpty &&
        _isOverwritable(translation, _lastAutoTranslation)) {
      translation.text = nextTranslation;
      _lastAutoTranslation = nextTranslation;
    }
    final nextPronunciation = filled.pronunciation?.trim();
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

  @override
  void dispose() {
    _disposed = true;
    text.dispose();
    translation.dispose();
    pronunciation.dispose();
    super.dispose();
  }
}
