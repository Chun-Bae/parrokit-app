// 뜻과 발음을 이미 적어 둔 단어에서 '뜻·발음 채우기'를 눌러도 아무 일이
// 없던 것(5차 525).
//
// _fillBasics는 둘 다 차 있으면 서버를 부르지 않고 돌아선다(한도를 아끼려는
// 것이라 맞다). 그런데 단추는 파랗게 켜진 채였고 까닭은 시트 맨 아래
// _notice에만 적혀서, 예문 칸을 다 지나 내려가야 보였다. 기기에서 세 번
// 눌러 보고서야 알았다. 506·515·519에서 고친 것과 같은 결함이다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_edit_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingAssist implements SentenceAssist {
  int calls = 0;

  @override
  int? get remainingToday => 3;
  @override
  int? get dailyLimit => 3;
  @override
  int? get examplesRemainingToday => 5;
  @override
  int? get exampleDailyLimit => 5;
  @override
  int? get maxExamplesPerWord => 3;

  @override
  int? get exampleCredits => null;

  @override
  int? get assistCredits => null;
  @override
  Future<void> refreshUsage() async {}
  @override
  Future<SentenceSuggestion> suggest(
          {required String language, required String text}) async =>
      const SentenceSuggestion();
  @override
  Future<String?> transliterate(
          {required String language, required String hangul}) async =>
      null;

  @override
  Future<String?> compose({
    required String language,
    required String meaning,
  }) async =>
      null;
  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) async {
    calls++;
    return const WordSuggestion(translation: '경향', pronunciation: '트렌드');
  }
}

Future<MyWord> _addWord({String meaning = '', String pronunciation = ''}) async {
  await MyWordStore.add('guest',
      language: '영어',
      word: 'trend',
      meaning: meaning,
      pronunciation: pronunciation);
  return (await MyWordStore.loadFor('guest', '영어')).single;
}

Future<void> _open(WidgetTester tester, MyWord word, SentenceAssist assist) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: WordEditSheet(word: word, accountId: 'guest', assist: assist),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

String _hint(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('edit-word-autofill-hint')))
    .data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('둘 다 차 있으면 단추를 막고 까닭을 단추 아래에 적는다', (tester) async {
    final word = await _addWord(meaning: '경향', pronunciation: '트렌드');
    final assist = _CountingAssist();
    await _open(tester, word, assist);

    expect(_hint(tester), wordFillBasicsDoneHint);
    final button = tester.widget<TextButton>(
        find.byKey(const ValueKey('edit-word-fill')));
    expect(button.onPressed, isNull, reason: '눌러도 할 일이 없으면 꺼 둔다');

    // 막혀 있으니 서버를 부르지 않는다.
    await tester.tap(find.byKey(const ValueKey('edit-word-fill')),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(assist.calls, 0);
  });

  testWidgets('한쪽만 비어 있으면 아직 채울 수 있다', (tester) async {
    final word = await _addWord(meaning: '경향');
    await _open(tester, word, _CountingAssist());

    expect(_hint(tester), wordFillBasicsHint);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('edit-word-fill')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('채우고 나면 그 자리에서 단추가 꺼진다', (tester) async {
    final word = await _addWord();
    final assist = _CountingAssist();
    await _open(tester, word, assist);

    expect(_hint(tester), wordFillBasicsHint);
    await tester.tap(find.byKey(const ValueKey('edit-word-fill')));
    await tester.pumpAndSettle();

    expect(assist.calls, 1);
    expect(_hint(tester), wordFillBasicsDoneHint);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('edit-word-fill')))
          .onPressed,
      isNull,
      reason: '한 번 채우면 끝이다. 또 누르면 한도만 쓴다',
    );
  });

  testWidgets('손으로 적어 넣어도 단추가 꺼진다', (tester) async {
    final word = await _addWord(meaning: '경향');
    await _open(tester, word, _CountingAssist());

    await tester.enterText(
        find.byKey(const ValueKey('edit-word-pronunciation-input')), '트렌드');
    await tester.pumpAndSettle();

    expect(_hint(tester), wordFillBasicsDoneHint);
  });
}
