// 낱말의 뜻과 예문을 자동으로 받아 넣는다(5차 467, 사용자 요청).
//
// 직접 더한 낱말에는 예문이 없어 쓰임을 볼 길이 없었다. 서버에 지금 들고
// 있는 예문을 함께 보내, 그것과 겹치지 않는 것만 받는다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAssist implements SentenceAssist {
  _FakeAssist({
    this.examples = const [],
    this.translation,
    this.pronunciation,
    this.limit,
    this.remaining,
    this.examplesRemaining,
    this.afterRefreshExamplesRemaining,
    this.afterRefreshMaxPerWord,
  });

  final int? limit;
  final int? remaining;

  /// 열릴 때 아는 값. null이면 아직 서버에 묻기 전이다.
  int? examplesRemaining;
  int? maxPerWord;

  /// refreshUsage가 돌고 나서 알게 되는 값.
  final int? afterRefreshExamplesRemaining;
  final int? afterRefreshMaxPerWord;

  final List<SuggestedExample> examples;
  final String? translation;
  final String? pronunciation;

  /// 마지막으로 서버에 보낸 값.
  List<String>? sentExisting;
  int? sentCount;
  String? sentWord;

  @override
  int? get remainingToday => remaining;
  @override
  int? get dailyLimit => limit;

  @override
  int? get examplesRemainingToday => examplesRemaining;

  @override
  int? get exampleDailyLimit => null;

  @override
  int? get maxExamplesPerWord => maxPerWord;

  @override
  int? get exampleCredits => null;

  @override
  int? get assistCredits => null;
  /// refreshUsage를 몇 번 불렀나. 시트가 열릴 때 한 번 부르므로, 두 번째
  /// 부터 값을 알려 줘야 '열 때는 몰랐다가 눌러서 안다'를 흉내 낼 수 있다.
  int refreshCount = 0;

  @override
  Future<void> refreshUsage() async {
    refreshCount++;
    if (refreshCount < 2) return;
    if (afterRefreshExamplesRemaining != null) {
      examplesRemaining = afterRefreshExamplesRemaining;
    }
    if (afterRefreshMaxPerWord != null) maxPerWord = afterRefreshMaxPerWord;
  }

  @override
  Future<SentenceSuggestion> suggest({
    required String language,
    required String text,
  }) async =>
      const SentenceSuggestion();

  @override
  Future<SentenceComplete> complete({
    required String language,
    String text = '',
    String translation = '',
    String pronunciation = '',
  }) async =>
      const SentenceComplete();

  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) async {
    sentWord = word;
    sentExisting = existingExamples;
    sentCount = count;
    return WordSuggestion(
      translation: translation,
      pronunciation: pronunciation,
      examples: examples,
    );
  }
}

Future<MyWord> _addWord({String? example}) async {
  await MyWordStore.add('guest',
      language: '영어', word: 'huge', example: example ?? '');
  return (await MyWordStore.loadFor('guest', '영어')).single;
}

Future<void> _openDetail(
  WidgetTester tester,
  MyWord word,
  SentenceAssist assist,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showWordDetails(context,
              word: word, accountId: 'guest', assist: assist),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

/// 예문 한도를 다 썼다고 서버가 거절하는 가짜(5차 517).
///
/// 서버는 뜻·발음 한도와 예문 한도를 모두 resource-exhausted로 돌려준다.
/// 어느 쪽인지 섞이면 멀쩡한 단추가 꺼지고 다 쓴 단추가 열린 채로 남는다.
class _ExampleQuotaAssist extends _FakeAssist {
  _ExampleQuotaAssist()
      : super(limit: 5, remaining: 5, examplesRemaining: 1) {
    maxPerWord = 3;
  }

  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) async {
    examplesRemaining = 0;
    throw const SentenceAssistQuotaExceeded(examples: true);
  }
}

/// refreshUsage가 끝나지 않고 매달려 있는 가짜. '횟수 확인 중' 상태를
/// 그대로 붙잡아 둔다.
class _SlowAssist extends _FakeAssist {
  _SlowAssist() : super(limit: 3, remaining: 3, examplesRemaining: 3);

  final Completer<void> _gate = Completer<void>();

  void finish() => _gate.complete();

  @override
  Future<void> refreshUsage() => _gate.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));



  test('예문은 상한까지만 들어간다', () async {
    final word = await _addWord();
    for (var i = 0; i < examplesMaxCount + 3; i++) {
      await MyWordStore.addExample(
          'guest', word.id, WordExample(text: '예문 $i'));
    }
    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.examples.length, examplesMaxCount);
  });

  testWidgets('고치기 창에서도 자동으로 채운다(5차 470)', (tester) async {
    final word = await _addWord();
    final assist = _FakeAssist(
      translation: '거대한',
      pronunciation: '휴지',
      examples: const [SuggestedExample(text: 'A huge wave.', translation: '큰 파도.')],
    );

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();
    // 상세로 나가지 않고 이 창 안에서 받는다.
    await tester.tap(find.byKey(const ValueKey('edit-word-fill-examples')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example-count-1')));
    await tester.pumpAndSettle();

    // 예문 단추이므로 예문만 들어간다. 뜻·발음은 위 단추가 맡는다.
    expect(find.text('A huge wave.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('edit-word-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-word-save')));
    await tester.pumpAndSettle();

    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.examples.single.text, 'A huge wave.');
  });

  testWidgets('고치기 창의 뜻·발음 단추는 예문을 만들지 않는다(5차 472)', (tester) async {
    final word = await _addWord();
    final assist = _FakeAssist(translation: '거대한', pronunciation: '휴지');

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-word-fill')));
    await tester.pumpAndSettle();

    // 예문을 만들지 말라고 0을 보낸다.
    expect(assist.sentCount, 0);
    expect(find.text('거대한'), findsOneWidget);
    expect(find.text('휴지'), findsOneWidget);
  });

  testWidgets('직접 적어 둔 뜻은 덮지 않는다', (tester) async {
    await MyWordStore.add('guest',
        language: '영어', word: 'huge', meaning: '내가 적은 뜻');
    final word = (await MyWordStore.loadFor('guest', '영어')).single;
    final assist = _FakeAssist(translation: '서버가 준 뜻', pronunciation: '휴지');

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-word-fill')));
    await tester.pumpAndSettle();

    // 상세 시트가 뒤에 남아 있어 같은 글이 둘 보인다.
    expect(find.text('내가 적은 뜻'), findsWidgets);
    expect(find.text('서버가 준 뜻'), findsNothing);
    // 비어 있던 발음만 찬다.
    expect(find.text('휴지'), findsOneWidget);
  });

  test('뜻·발음과 예문 채우기를 나눠 두고 설명도 따로 쓴다(5차 472)', () {
    for (final path in [
      'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('wordFillBasicsHint'), isTrue, reason: path);
      expect(src.contains('wordFillExamplesHint'), isTrue, reason: path);
    }
  });

  test('단추가 저마다 제 자리에 있다(5차 472)', () {
    // 뜻·발음 단추는 뜻 칸보다 앞, 예문 단추는 예문 칸 옆이다.
    final src = File(
            'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart')
        .readAsStringSync();
    final basics = src.indexOf("ValueKey('fill-word-meaning')");
    final meaning = src.indexOf("ValueKey('word-meaning')");
    final example = src.indexOf("ValueKey('word-example-" r"$index')");
    final fillExamples = src.indexOf("ValueKey('fill-word-examples')");
    expect(basics, greaterThan(-1));
    expect(basics, lessThan(meaning), reason: '뜻·발음 단추가 뜻 칸보다 앞');
    expect(fillExamples, greaterThan(example),
        reason: '예문 단추는 예문 칸 뒤에 와야 한다');
  });

  test('보기만 하는 상세에는 채우기 단추가 없다(5차 472)', () {
    final src = File(
            'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart')
        .readAsStringSync();
    // 상세 시트의 단추는 뺐다. 추가 시트의 것만 남는다.
    expect('ValueKey(\'fill-word-examples\')'.allMatches(src).length, 1);
  });

  test('오늘 다 썼는지 센다(5차 473)', () {
    expect(assistExhausted(used: 3, limit: 3), isTrue);
    expect(assistExhausted(used: 2, limit: 3), isFalse);
    // 모르면 막지 않는다. 서버가 막으면 그때 알린다.
    expect(assistExhausted(used: null, limit: 3), isFalse);
    expect(assistExhausted(used: 3, limit: null), isFalse);
  });

  test('다 썼다는 말을 한 곳에서 꺼내 쓴다(5차 473)', () {
    expect(assistQuotaExhaustedMessage, contains('내일'));
    for (final path in [
      'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
    ]) {
      final src = File(path)
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      // 상수 선언 말고는 손으로 적힌 자리가 없어야 한다.
      final handWritten = "'오늘 자동 채우기를 모두 썼어요".allMatches(src).length;
      final declared = src.contains('const String assistQuotaExhaustedMessage');
      expect(handWritten, declared ? 1 : 0, reason: path);
    }
  });

  testWidgets('오늘 다 썼으면 단추를 막고 까닭을 미리 보여 준다(5차 473)', (tester) async {
    final word = await _addWord();
    // 뜻·발음 채우기는 다 썼지만 예문은 남았다. 두 한도는 다른 축이라
    // 예문 단추는 열려 있어야 한다.
    final assist = _FakeAssist(limit: 3, remaining: 0, examplesRemaining: 2);

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();

    // 눌러 보기 전에 까닭이 보인다.
    expect(find.text(assistQuotaExhaustedMessage), findsWidgets);
    final fill = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('edit-word-fill')));
    expect(fill.onPressed, isNull);
    final examples = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('edit-word-fill-examples')));
    expect(examples.onPressed, isNotNull);
  });

  testWidgets('오늘 예문을 다 만들었으면 예문 단추만 막는다', (tester) async {
    final word = await _addWord();
    final assist = _FakeAssist(limit: 3, remaining: 2, examplesRemaining: 0);

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();

    expect(find.text(exampleQuotaExhaustedText), findsOneWidget);
    final fill = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('edit-word-fill')));
    expect(fill.onPressed, isNotNull);
    final examples = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('edit-word-fill-examples')));
    expect(examples.onPressed, isNull);
  });

  // 횟수를 묻는 동안에는 채우기 단추를 막는다(5차 515, 사용자 요청).
  // 전에는 '횟수 확인 중…'이 떠 있는데도 눌려서, 다 쓴 사람도 눌러 본
  // 뒤에야 막혔다는 걸 알았다.
  testWidgets('횟수 확인 중에는 뜻·발음 채우기를 막는다', (tester) async {
    final word = await _addWord();
    final assist = _SlowAssist();

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pump();

    final whileLoading = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('edit-word-fill')));
    expect(whileLoading.onPressed, isNull, reason: '묻는 동안에는 막혀 있어야 한다');

    assist.finish();
    await tester.pumpAndSettle();

    final afterLoading = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('edit-word-fill')));
    expect(afterLoading.onPressed, isNotNull, reason: '다 물으면 다시 열려야 한다');
  });

  // 열 때는 한도를 몰라 단추가 열려 있다. 눌러서 그제야 0인 걸 알면,
  // 까닭을 단추 아래에 한 번만 적어야 한다. 전에는 거기에 더해 시트 맨
  // 아래 알림줄에도 같은 문장을 넣어 두 번 나왔다(5차 513).
  testWidgets('눌러서 한도 소진을 알게 돼도 안내는 한 번만 나온다', (tester) async {
    final word = await _addWord();
    final assist = _FakeAssist(
      limit: 3,
      remaining: 2,
      afterRefreshExamplesRemaining: 0,
      afterRefreshMaxPerWord: 3,
    );

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-word-fill-examples')));
    await tester.pumpAndSettle();

    expect(find.text(exampleQuotaExhaustedText), findsOneWidget);
  });

  testWidgets('남았으면 단추를 막지 않는다(5차 473)', (tester) async {
    final word = await _addWord();
    final assist = _FakeAssist(limit: 3, remaining: 2);

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();

    for (final key in ['edit-word-fill', 'edit-word-fill-examples']) {
      final button = tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key)));
      expect(button.onPressed, isNotNull, reason: key);
    }
  });

  test('개수 고르기 창을 두 화면이 함께 쓴다(5차 474)', () {
    // 전에는 고치기 창에만 있어서, 추가 시트에서는 몇 개가 오는지도
    // 상한이 몇 개인지도 알 수 없었다.
    final sheet = File(
            'lib/features/collection/shell/presentation/widgets/example_count_sheet.dart')
        .readAsStringSync();
    // 상한은 서버가 단계별로 알려 주므로 상수가 아니라 maxPerWord로 받는다.
    // 모를 때는 숫자를 단언하지 않는다(5차 507).
    expect(sheet, contains('maxPerWord'), reason: '상한을 서버 값으로 받는다');
    expect(sheet, contains('개까지 둘 수 있어요'), reason: '상한을 적어 준다');

    for (final path in [
      'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('askExampleCount('),
          reason: path);
    }
  });

  test('상한은 서버와 같은 10개다', () {
    expect(examplesMaxCount, 10);
  });

  test('발음은 예전에 저장한 단어에 없어도 읽힌다', () {
    // 예전 형식에는 pronunciation 칸이 아예 없다(5차 468).
    final old = MyWord.fromJson({
      'id': 'en:huge',
      'language': '영어',
      'word': 'huge',
      'meaning': '거대한',
    });
    expect(old, isNotNull);
    expect(old!.pronunciation, '');

    final now = MyWord.fromJson({
      ...old.toJson(),
      'pronunciation': '휴지',
    });
    expect(now!.pronunciation, '휴지');
  });

  test('발음만 고쳐도 나머지는 그대로다', () async {
    await MyWordStore.add('guest',
        language: '영어',
        word: 'huge',
        meaning: '거대한',
        example: '예문',
        synonyms: const ['big']);
    final word = (await MyWordStore.loadFor('guest', '영어')).single;

    expect(await MyWordStore.setPronunciation('guest', word.id, ' 휴지 '),
        isTrue);
    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.pronunciation, '휴지');
    expect(after.meaning, '거대한');
    expect(after.synonyms, ['big']);
    expect(after.examples.single.text, '예문');
  });

  testWidgets('예문 한도를 다 쓰면 예문 쪽 말을 적는다(5차 517)', (tester) async {
    final word = await _addWord();
    final assist = _ExampleQuotaAssist();

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-word-fill-examples')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example-count-1')));
    await tester.pumpAndSettle();

    final notice =
        tester.widget<Text>(find.byKey(const ValueKey('edit-word-notice')));
    expect(notice.data, exampleQuotaExhaustedText,
        reason: '다 쓴 것은 예문 한도다');
    expect(find.text(assistQuotaExhaustedMessage), findsNothing,
        reason: '뜻·발음 한도는 그대로 남아 있다');
  });
}
