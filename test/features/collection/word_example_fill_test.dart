// 낱말의 뜻과 예문을 자동으로 받아 넣는다(5차 467, 사용자 요청).
//
// 직접 더한 낱말에는 예문이 없어 쓰임을 볼 길이 없었다. 서버에 지금 들고
// 있는 예문을 함께 보내, 그것과 겹치지 않는 것만 받는다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAssist implements SentenceAssist {
  _FakeAssist({
    this.examples = const [],
    this.translation,
    this.pronunciation,
  });

  final List<SuggestedExample> examples;
  final String? translation;
  final String? pronunciation;

  /// 마지막으로 서버에 보낸 값.
  List<String>? sentExisting;
  int? sentCount;
  String? sentWord;

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
  }) async =>
      const SentenceSuggestion();

  @override
  Future<String?> transliterate({
    required String language,
    required String hangul,
  }) async =>
      null;

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
    await tester.tap(find.byKey(const ValueKey('edit-word-fill-count-1')));
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

}

