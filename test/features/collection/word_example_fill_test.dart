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

  testWidgets('받은 예문과 뜻을 넣고, 들고 있던 예문을 서버에 함께 보낸다', (tester) async {
    final word = await _addWord(example: '이미 있는 예문');
    final assist = _FakeAssist(
      translation: '거대한',
      examples: const [
        SuggestedExample(text: 'A huge wave.', translation: '큰 파도.'),
        SuggestedExample(text: 'A huge crowd.', translation: '큰 무리.'),
      ],
    );

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('fill-word-examples')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example-count-2')));
    await tester.pumpAndSettle();

    expect(assist.sentWord, 'huge');
    expect(assist.sentExisting, ['이미 있는 예문'], reason: '겹치지 않게 보낸다');
    expect(assist.sentCount, 2);

    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.examples.map((e) => e.text),
        ['이미 있는 예문', 'A huge wave.', 'A huge crowd.']);
    expect(after.meaning, '거대한', reason: '뜻이 비어 있으면 함께 채운다');
  });

  testWidgets('직접 적어 둔 뜻은 덮지 않는다', (tester) async {
    await MyWordStore.add('guest',
        language: '영어', word: 'huge', meaning: '내가 적은 뜻');
    final word = (await MyWordStore.loadFor('guest', '영어')).single;
    final assist = _FakeAssist(
      translation: '서버가 준 뜻',
      examples: const [SuggestedExample(text: 'A huge wave.')],
    );

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('fill-word-examples')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example-count-1')));
    await tester.pumpAndSettle();

    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.meaning, '내가 적은 뜻');
  });

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
    await tester.tap(find.byKey(const ValueKey('edit-word-fill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-word-fill-count-1')));
    await tester.pumpAndSettle();

    // 아직 저장 전이라 입력칸에만 들어간다.
    expect(find.text('거대한'), findsOneWidget);
    expect(find.text('휴지'), findsOneWidget);
    expect(find.text('A huge wave.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('edit-word-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-word-save')));
    await tester.pumpAndSettle();

    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.meaning, '거대한');
    expect(after.pronunciation, '휴지');
    expect(after.examples.single.text, 'A huge wave.');
  });

  test('두 화면이 자동 채우기 설명을 한 곳에서 꺼내 쓴다(5차 471)', () {
    expect(wordAutoFillHint, contains('예문'));
    for (final path in [
      'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src.contains('wordAutoFillHint'), isTrue, reason: path);
    }
  });

  test('추가 시트는 단추를 입력칸보다 먼저 둔다(5차 471)', () {
    // 뜻·발음 칸 아래에 있으면 그 둘만 채우는 줄 안다. 예문 칸은 한참 밑이다.
    final src = File(
            'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart')
        .readAsStringSync();
    final button = src.indexOf("ValueKey('fill-word-meaning')");
    final meaning = src.indexOf("ValueKey('word-meaning')");
    final example = src.indexOf("ValueKey('word-example-" r"$index')");
    expect(button, greaterThan(-1));
    expect(button, lessThan(meaning), reason: '단추가 뜻 칸보다 앞에 와야 한다');
    expect(button, lessThan(example));
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

  testWidgets('자동으로 넣기가 발음도 채운다', (tester) async {
    final word = await _addWord();
    final assist = _FakeAssist(
      translation: '거대한',
      pronunciation: '휴지',
      examples: const [SuggestedExample(text: 'A huge wave.')],
    );

    await _openDetail(tester, word, assist);
    await tester.tap(find.byKey(const ValueKey('fill-word-examples')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example-count-1')));
    await tester.pumpAndSettle();

    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.pronunciation, '휴지');
  });
}

