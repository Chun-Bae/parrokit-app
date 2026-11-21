import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/add_sentence_controller.dart';
import 'package:parrokit/core/content/sentence_assist.dart';

class FakeAssist implements SentenceAssist {
  @override
  int? remainingToday;
  @override
  int? dailyLimit;
  @override
  int? examplesRemainingToday;
  @override
  int? exampleDailyLimit;
  @override
  int? maxExamplesPerWord;

  @override
  int? exampleCredits;

  @override
  int? assistCredits;
  int refreshCalls = 0;
  final suggestCalls = <String>[];
  Future<SentenceSuggestion> Function(String text)? onSuggest;
  Future<String?> Function(String hangul)? onTransliterate;

  @override
  Future<void> refreshUsage() async {
    refreshCalls++;
  }

  @override
  Future<SentenceSuggestion> suggest(
      {required String language, required String text}) {
    suggestCalls.add(text);
    return onSuggest?.call(text) ??
        Future.value(SentenceSuggestion(
            translation: '뜻:$text', pronunciation: '발:$text'));
  }

  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) async =>
      const WordSuggestion();

  @override
  Future<String?> transliterate(
          {required String language, required String hangul}) =>
      onTransliterate?.call(hangul) ?? Future.value('변환:$hangul');
}

AddSentenceController make(FakeAssist assist, {String language = '영어'}) =>
    AddSentenceController(language: language, assist: assist);

void main() {
  _exhaustedTests();
  test('추가할 수 없으면 무엇이 빠졌는지 알려 준다', () {
    // 꺼진 '추가'만 보고는 알 수 없었다(5차, 커뮤니티 글쓰기와 같은 결).
    final c = make(FakeAssist());
    addTearDown(c.dispose);

    expect(c.blockedReason, '문장을 적어 주세요.');
    expect(c.canSave, isFalse);

    c.text.text = 'Could you give me a hand?';
    expect(c.blockedReason, '뜻을 적어 주세요.');

    c.translation.text = '도와줄 수 있어요?';
    expect(c.blockedReason, isNull);
    expect(c.canSave, isTrue);
  });

  test('입력만으로는 요청하지 않아 횟수를 쓰지 않는다', () async {
    final assist = FakeAssist();
    final c = make(assist);
    c.text.text = 'Hello';
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(assist.suggestCalls, isEmpty);
    c.dispose();
  });

  test('채우기(fill)를 부르면 뜻과 발음을 채운다', () async {
    final assist = FakeAssist();
    final c = make(assist);
    c.text.text = 'Hello';
    await c.fill();
    expect(assist.suggestCalls, ['Hello']);
    expect(c.translation.text, '뜻:Hello');
    expect(c.pronunciation.text, '발:Hello');
    expect(c.fillStatus, AssistStatus.idle);
    c.dispose();
  });

  test('원문이 비어 있으면 요청하지 않는다', () async {
    final assist = FakeAssist();
    final c = make(assist);
    await c.fill();
    expect(assist.suggestCalls, isEmpty);
    c.dispose();
  });

  test('직접 쓴 칸은 덮어쓰지 않고 자동으로 채운 칸만 새 제안으로 바꾼다', () async {
    final assist = FakeAssist();
    final c = make(assist);
    c.text.text = 'Hi';
    await c.fill();
    expect(c.translation.text, '뜻:Hi');
    c.pronunciation.text = '내가 쓴 발음';
    c.text.text = 'Hi there';
    await c.fill();
    expect(c.translation.text, '뜻:Hi there');
    expect(c.pronunciation.text, '내가 쓴 발음');
    c.dispose();
  });

  test('늦게 도착한 오래된 응답은 버린다', () async {
    final assist = FakeAssist();
    final first = <String, Future<SentenceSuggestion>>{};
    assist.onSuggest = (text) => first.putIfAbsent(
        text,
        () => Future.delayed(Duration(milliseconds: text == 'old' ? 200 : 10),
            () => SentenceSuggestion(translation: '뜻:$text')));
    final c = make(assist);
    c.text.text = 'old';
    final oldCall = c.fill();
    c.text.text = 'new';
    final newCall = c.fill();
    await Future.wait([oldCall, newCall]);
    expect(c.translation.text, '뜻:new');
    c.dispose();
  });

  test('도우미가 연결되지 않았으면 unavailable로 두고 직접 입력으로 돌아간다', () async {
    final c = AddSentenceController(
        language: '영어', assist: const UnavailableSentenceAssist());
    c.text.text = 'Hello';
    await c.fill();
    expect(c.fillStatus, AssistStatus.unavailable);
    expect(c.translation.text, isEmpty);
    c.dispose();
  });

  test('오늘 횟수를 다 쓰면 quotaExceeded가 된다', () async {
    final assist = FakeAssist()
      ..onSuggest = (_) => Future.error(const SentenceAssistQuotaExceeded());
    final c = make(assist);
    c.text.text = 'Hello';
    await c.fill();
    expect(c.fillStatus, AssistStatus.quotaExceeded);
    c.dispose();
  });

  test('요청이 실패하면 failed로 두고 다시 채울 수 있다', () async {
    final assist = FakeAssist()
      ..onSuggest = (_) => Future.error(Exception('network'));
    final c = make(assist);
    c.text.text = 'Hello';
    await c.fill();
    expect(c.fillStatus, AssistStatus.failed);
    assist.onSuggest = null;
    await c.fill();
    expect(c.translation.text, '뜻:Hello');
    expect(c.fillStatus, AssistStatus.idle);
    c.dispose();
  });

  test('남은 횟수는 도우미가 알려 준 값을 그대로 보여준다', () async {
    final assist = FakeAssist();
    assist.onSuggest = (_) async {
      assist.remainingToday = 2;
      return const SentenceSuggestion(translation: '안녕');
    };
    final c = make(assist);
    expect(c.remainingToday, isNull);
    c.text.text = 'Hello';
    await c.fill();
    expect(c.remainingToday, 2);
    c.dispose();
  });

  test('저장은 원문과 뜻이 있어야 하고 발음은 선택이다', () {
    final c = make(FakeAssist());
    expect(c.canSave, isFalse);
    c.text.text = '  Hello  ';
    expect(c.canSave, isFalse);
    c.translation.text = ' 안녕 ';
    expect(c.canSave, isTrue);
    final built = c.build()!;
    expect(built.text, 'Hello');
    expect(built.translation, '안녕');
    expect(built.pronunciation, '');
    c.dispose();
  });

  test('한글 전사는 일본어와 중국어에서만 쓰고 결과를 원문칸에 넣는다', () async {
    expect(make(FakeAssist()).canTransliterate, isFalse);
    final c = make(FakeAssist(), language: '일본어');
    expect(c.canTransliterate, isTrue);
    c.hangul.text = '곤니치와';
    await c.transliterate();
    expect(c.text.text, '변환:곤니치와');
    expect(c.transliterateStatus, AssistStatus.idle);
    c.dispose();
  });

  test('전사가 안 되면 상태만 바뀌고 원문은 그대로다', () async {
    final assist = FakeAssist()..onTransliterate = (_) async => null;
    final c = make(assist, language: '중국어');
    c.text.text = '你';
    c.hangul.text = '니하오';
    await c.transliterate();
    expect(c.transliterateStatus, AssistStatus.failed);
    expect(c.text.text, '你');
    final unavailable = AddSentenceController(
        language: '중국어', assist: const UnavailableSentenceAssist())
      ..hangul.text = '니하오';
    await unavailable.transliterate();
    expect(unavailable.transliterateStatus, AssistStatus.unavailable);
    c.dispose();
    unavailable.dispose();
  });

  test('한글 전사도 횟수를 다 쓰면 quotaExceeded가 된다', () async {
    final assist = FakeAssist()
      ..onTransliterate =
          (_) => Future.error(const SentenceAssistQuotaExceeded());
    final c = AddSentenceController(language: '일본어', assist: assist);
    c.hangul.text = '곤니치와';
    await c.transliterate();
    expect(c.transliterateStatus, AssistStatus.quotaExceeded);
    c.dispose();
  });

  test('언어를 바꾸면 전사 가능 여부와 저장 언어가 바뀐다', () {
    final c = make(FakeAssist());
    expect(c.canTransliterate, isFalse);
    c.setLanguage('일본어');
    expect(c.canTransliterate, isTrue);
    c.text.text = 'こんにちは';
    c.translation.text = '안녕하세요';
    expect(c.build()!.language, '일본어');
    c.dispose();
  });

  test('오늘 쓴 횟수는 한도에서 남은 횟수를 뺀 값이고, 모르면 null이다', () async {
    final assist = FakeAssist();
    final c = make(assist);
    expect(c.usedToday, isNull);
    assist
      ..dailyLimit = 3
      ..remainingToday = 1;
    expect(c.usedToday, 2);
    assist.remainingToday = 5; // 한도보다 크게 와도 음수가 되지 않는다.
    expect(c.usedToday, 0);
    c.dispose();
  });

  test('loadUsage는 서버에서 횟수만 새로 읽고 알린다', () async {
    final assist = FakeAssist();
    final c = make(assist);
    var notified = 0;
    c.addListener(() => notified++);
    await c.loadUsage();
    expect(assist.refreshCalls, 1);
    expect(assist.suggestCalls, isEmpty);
    expect(notified, 2); // 읽는 중, 읽은 뒤
    c.dispose();
  });

  test('횟수를 읽었는지 여부를 usageStatus로 알려 준다', () async {
    final assist = FakeAssist();
    final c = make(assist);
    expect(c.usageStatus, UsageStatus.loading);
    await c.loadUsage();
    expect(c.usageStatus, UsageStatus.unknown); // 서버가 값을 안 줬다.
    assist
      ..dailyLimit = 3
      ..remainingToday = 3;
    await c.loadUsage();
    expect(c.usageStatus, UsageStatus.ready);
    c.dispose();
  });
}

// 다 쓴 줄을 눌러 보기 전에 안다(5차 478).
//
// 전에는 서버가 거절해야 fillStatus가 quotaExceeded가 됐다. 그래서 열자마자
// 3/3인 화면이 '문장을 적으면 채울 수 있어요'라고 적고, 적어도 단추는 죽어
// 있었다.
void _exhaustedTests() {
  test('횟수를 다 썼으면 부르기 전에도 안다', () {
    final assist = FakeAssist()
      ..dailyLimit = 3
      ..remainingToday = 0;
    final controller = make(assist);
    expect(controller.usedToday, 3);
    expect(controller.exhausted, isTrue);
  });

  test('남아 있으면 막지 않는다', () {
    final assist = FakeAssist()
      ..dailyLimit = 3
      ..remainingToday = 1;
    expect(make(assist).exhausted, isFalse);
  });

  test('횟수를 모르면 막지 않는다', () {
    expect(make(FakeAssist()).exhausted, isFalse);
  });

  // 손으로 다 적어 두면 채우기가 덮어쓸 자리가 없다. 그런데도 서버를 불러
  // 하루 횟수만 한 번 버렸다(5차 526). 기기에서 3/3을 그렇게 채웠다.
  group('채울 자리가 없을 때', () {
    test('손으로 둘 다 적었으면 부르지 않는다', () async {
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      final controller = AddSentenceController(assist: assist, language: '영어');
      controller.text.text = 'Hello';
      controller.translation.text = '내가 적은 뜻';
      controller.pronunciation.text = '내가 적은 발음';

      expect(controller.hasFillRoom, isFalse);
      await controller.fill();
      expect(assist.suggestCalls, isEmpty);
      controller.dispose();
    });

    test('한쪽만 적었으면 아직 부를 수 있다', () async {
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      final controller = AddSentenceController(assist: assist, language: '영어');
      controller.text.text = 'Hello';
      controller.translation.text = '내가 적은 뜻';

      expect(controller.hasFillRoom, isTrue);
      await controller.fill();
      expect(assist.suggestCalls, ['Hello']);
      // 손으로 적은 뜻은 그대로 두고 발음만 채운다.
      expect(controller.translation.text, '내가 적은 뜻');
      expect(controller.pronunciation.text, '발:Hello');
      controller.dispose();
    });

    test('자동으로 채운 값만 있으면 다시 받을 수 있다', () async {
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      final controller = AddSentenceController(assist: assist, language: '영어');
      controller.text.text = 'Hello';

      await controller.fill();
      expect(assist.suggestCalls.length, 1);
      // 자동으로 채운 값 그대로면 '다시 받기'를 막지 않는다.
      expect(controller.hasFillRoom, isTrue);
      await controller.fill();
      expect(assist.suggestCalls.length, 2);
      controller.dispose();
    });
  });

  // 한글 전사로 적은 소리가 곧 발음인데 발음칸에 똑같이 다시 쳐야 했다
  // (5차 539, 사용자 요청).
  group('적어 둔 한글 소리 가져오기', () {
    AddSentenceController make({String language = '일본어'}) {
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      return AddSentenceController(assist: assist, language: language);
    }

    test('적어 둔 소리가 있으면 가져올 수 있다', () {
      final c = make();
      c.hangul.text = '곤니치와';

      expect(c.canCopyHangul, isTrue);
      c.copyHangulToPronunciation();
      expect(c.pronunciation.text, '곤니치와');
      c.dispose();
    });

    test('적어 둔 소리가 없으면 권하지 않는다', () {
      final c = make();
      expect(c.canCopyHangul, isFalse);
      c.hangul.text = '   ';
      expect(c.canCopyHangul, isFalse);
      c.dispose();
    });

    test('한글 전사를 안 쓰는 언어에는 없다', () {
      final c = make(language: '영어');
      c.hangul.text = '헬로';
      expect(c.canCopyHangul, isFalse);
      c.dispose();
    });

    test('손으로 적어 둔 발음은 덮지 않는다', () {
      final c = make();
      c.hangul.text = '곤니치와';
      c.pronunciation.text = '내가 적은 발음';

      expect(c.canCopyHangul, isFalse);
      c.copyHangulToPronunciation();
      expect(c.pronunciation.text, '내가 적은 발음');
      c.dispose();
    });

    test('이미 같은 값이면 권하지 않는다', () {
      final c = make();
      c.hangul.text = '곤니치와';
      c.copyHangulToPronunciation();

      expect(c.canCopyHangul, isFalse);
      c.dispose();
    });

    test('가져온 값은 채우기가 덮어쓸 수 있다', () {
      // 자동으로 채운 것과 같이 다룬다. 그 뒤 '뜻·발음 채우기'를 눌러
      // 더 나은 발음이 오면 바뀌어야 한다.
      final c = make();
      c.hangul.text = '곤니치와';
      c.copyHangulToPronunciation();

      expect(c.hasFillRoom, isTrue);
      c.dispose();
    });
  });
}
