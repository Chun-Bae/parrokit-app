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

  /// fill()이 부른 원문. completeCalls의 첫 칸이다.
  List<String> get suggestCalls =>
      completeCalls.map((g) => g[0]).toList();
  Future<SentenceSuggestion> Function(String text)? onSuggest;

  /// complete에 넘어온 세 칸. ['원문', '뜻', '발음'] 꼴로 쌓인다.
  final completeCalls = <List<String>>[];
  Future<SentenceComplete> Function(List<String> given)? onComplete;

  @override
  Future<void> refreshUsage() async {
    refreshCalls++;
  }

  @override
  Future<SentenceSuggestion> suggest(
      {required String language, required String text}) {
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
  Future<SentenceComplete> complete({
    required String language,
    String text = '',
    String translation = '',
    String pronunciation = '',
  }) {
    final given = [text, translation, pronunciation];
    completeCalls.add(given);
    final seed = given.firstWhere((v) => v.isNotEmpty, orElse: () => '');
    // 서버는 빈 칸을 늘 새로 만들어 준다. 덮어쓸지 말지는 컨트롤러가 정한다.
    return onComplete?.call(given) ??
        Future.value(SentenceComplete(
          text: text.isNotEmpty ? text : '원문:$seed',
          translation: '뜻:$seed',
          pronunciation: '발:$seed',
        ));
  }
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
    // 원문만 손으로 고친다. 자동으로 채운 두 칸은 재료로 치지 않으므로
    // 다시 받을 수 있다(5차 553).
    c.text.text = 'Hi there';
    await c.fill();
    expect(c.translation.text, '뜻:Hi there');
    expect(c.pronunciation.text, '발:Hi there');

    // 손으로 적은 칸은 그대로 둔다.
    final typed = make(FakeAssist());
    typed.translation.text = '내가 적은 뜻';
    await typed.fill();
    expect(typed.translation.text, '내가 적은 뜻');
    typed.dispose();
    c.dispose();
  });

  test('늦게 도착한 오래된 응답은 버린다', () async {
    final assist = FakeAssist();
    final first = <String, Future<SentenceComplete>>{};
    assist.onComplete = (given) => first.putIfAbsent(
        given[0],
        () => Future.delayed(
            Duration(milliseconds: given[0] == 'old' ? 200 : 10),
            () => SentenceComplete(
                text: given[0], translation: '뜻:${given[0]}')));
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
      ..onComplete = (_) => Future.error(const SentenceAssistQuotaExceeded());
    final c = make(assist);
    c.text.text = 'Hello';
    await c.fill();
    expect(c.fillStatus, AssistStatus.quotaExceeded);
    c.dispose();
  });

  test('요청이 실패하면 failed로 두고 다시 채울 수 있다', () async {
    final assist = FakeAssist()
      ..onComplete = (_) => Future.error(Exception('network'));
    final c = make(assist);
    c.text.text = 'Hello';
    await c.fill();
    expect(c.fillStatus, AssistStatus.failed);
    assist.onComplete = null;
    await c.fill();
    expect(c.translation.text, '뜻:Hello');
    expect(c.fillStatus, AssistStatus.idle);
    c.dispose();
  });

  test('남은 횟수는 도우미가 알려 준 값을 그대로 보여준다', () async {
    final assist = FakeAssist();
    assist.onComplete = (_) async {
      assist.remainingToday = 2;
      return const SentenceComplete(translation: '안녕');
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

  test('언어를 바꾸면 저장 언어가 바뀐다', () {
    final c = make(FakeAssist());
    c.setLanguage('일본어');
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

    test('한쪽이 비었어도 손으로 둘을 적었으면 부르지 않는다', () async {
      // 발음을 채울 자리는 남아 있다. 그런데 원문과 뜻이 어긋나면 그
      // 발음을 어느 쪽에 맞출지 알 수 없다(5차 553, 사용자 결정).
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      final controller = AddSentenceController(assist: assist, language: '영어');
      controller.text.text = 'Hello';
      controller.translation.text = '내가 적은 뜻';

      expect(controller.hasFillRoom, isTrue, reason: '발음 자리는 비어 있다');
      expect(controller.hasRivalSources, isTrue);
      await controller.fill();
      expect(assist.suggestCalls, isEmpty);
      expect(controller.pronunciation.text, isEmpty);
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

  // 단추 하나가 빈 칸을 다 채운다(5차 545, 사용자 요청).
  group('빈 칸 채우기', () {
    AddSentenceController build({String language = '일본어'}) {
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      return AddSentenceController(assist: assist, language: language);
    }

    test('셋 다 비어 있으면 부르지 않는다', () async {
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      final c = AddSentenceController(assist: assist, language: '일본어');

      expect(c.hasFillSource, isFalse);
      await c.fill();
      expect(assist.completeCalls, isEmpty);
      c.dispose();
    });

    test('뜻만 적어도 부를 수 있다', () {
      final c = build();
      c.translation.text = '안녕하세요';
      expect(c.hasFillSource, isTrue);
      c.dispose();
    });

    test('발음만 적어도 부를 수 있다', () {
      final c = build();
      c.pronunciation.text = '곤니치와';
      expect(c.hasFillSource, isTrue);
      c.dispose();
    });

    test('뜻만 적고 누르면 한 번에 원문과 발음까지 채운다', () async {
      // 전에는 원문 생성 → 뜻발음 생성으로 두 번 불러 하루 횟수를 두 번
      // 썼다(5차 545).
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      final c = AddSentenceController(assist: assist, language: '일본어');
      c.translation.text = '안녕하세요';

      await c.fill();

      expect(assist.completeCalls, [
        ['', '안녕하세요', '']
      ], reason: '한 번만 부른다');
      expect(c.text.text, '원문:안녕하세요');
      expect(c.pronunciation.text, '발:안녕하세요');
      expect(c.translation.text, '안녕하세요', reason: '적어 둔 칸은 그대로다');
      expect(c.fillStatus, AssistStatus.idle);
      c.dispose();
    });

    test('손으로 적어 둔 칸은 덮지 않는다', () async {
      final c = build();
      c.text.text = '내가 적은 원문';
      c.translation.text = '내가 적은 뜻';
      c.pronunciation.text = '내가 적은 발음';

      expect(c.hasFillRoom, isFalse);
      await c.fill();
      expect(c.text.text, '내가 적은 원문');
      expect(c.translation.text, '내가 적은 뜻');
      expect(c.pronunciation.text, '내가 적은 발음');
      c.dispose();
    });

    test('자동으로 채운 칸은 다시 받을 수 있다', () async {
      final c = build();
      c.translation.text = '안녕하세요';
      await c.fill();

      expect(c.hasFillRoom, isTrue);
      c.dispose();
    });

    test('하루 횟수를 다 쓰면 그렇게 알린다', () async {
      final assist = FakeAssist()
        ..remainingToday = 0
        ..dailyLimit = 3
        ..onComplete =
            ((_) async => throw const SentenceAssistQuotaExceeded());
      final c = AddSentenceController(assist: assist, language: '일본어');
      c.translation.text = '안녕하세요';

      await c.fill();

      expect(c.fillStatus, AssistStatus.quotaExceeded);
      c.dispose();
    });

    test('연결되지 않았으면 unavailable로 둔다', () async {
      final c = AddSentenceController(
          language: '일본어', assist: const UnavailableSentenceAssist());
      c.translation.text = '안녕하세요';

      await c.fill();

      expect(c.fillStatus, AssistStatus.unavailable);
      c.dispose();
    });
  });

  // 원문을 뜻과 발음 둘에서 만들면 둘이 어긋났을 때 어느 쪽에도 맞출 수
  // 없다(5차 553, 사용자 요청). 원문이 있으면 그것이 기준이라 괜찮다.
  group('재료 둘이 다툴 때', () {
    AddSentenceController build() {
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      return AddSentenceController(assist: assist, language: '일본어');
    }

    test('손으로 둘을 적으면 막는다', () {
      for (final fill in <void Function(AddSentenceController)>[
        (c) => c
          ..translation.text = '안녕하세요'
          ..pronunciation.text = '아리가또',
        (c) => c
          ..text.text = 'こんにちは'
          ..translation.text = '안녕히 가세요',
        (c) => c
          ..text.text = 'こんにちは'
          ..pronunciation.text = '아리가또',
      ]) {
        final c = build();
        fill(c);
        expect(c.hasRivalSources, isTrue);
        c.dispose();
      }
    });

    test('막힌 자리에서는 불러도 서버를 안 부른다', () async {
      final assist = FakeAssist()
        ..remainingToday = 3
        ..dailyLimit = 3;
      final c = AddSentenceController(assist: assist, language: '일본어');
      c.translation.text = '안녕하세요';
      c.pronunciation.text = '아리가또';

      await c.fill();

      expect(assist.completeCalls, isEmpty);
      expect(c.text.text, isEmpty);
      c.dispose();
    });

    test('자동으로 채운 값은 재료로 치지 않는다', () {
      // 한 번 채우고 나면 셋이 다 차 있지만, 손으로 적은 것은 하나다.
      // 그것까지 세면 '다시 받기'를 할 수 없다.
      final c = build();
      c.translation.text = '안녕하세요';
      c.fill();
      return Future<void>.delayed(Duration.zero).then((_) {
        expect(c.typedFieldCount, 1);
        expect(c.hasRivalSources, isFalse);
        expect(c.hasFillRoom, isTrue);
        c.dispose();
      });
    });

    test('하나만 있으면 막지 않는다', () {
      final one = build()..translation.text = '안녕하세요';
      expect(one.hasRivalSources, isFalse);
      one.dispose();

      final other = build()..pronunciation.text = '곤니치와';
      expect(other.hasRivalSources, isFalse);
      other.dispose();
    });
  });
}
