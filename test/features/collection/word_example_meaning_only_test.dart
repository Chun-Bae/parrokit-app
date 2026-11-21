// 예문 뜻만 적어 둔 칸이 말없이 사라지던 것(5차 504).
//
// 고치기 창의 저장은 빈 예문 칸을 버린다(칸만 열어 두고 저장해도 괜찮아야
// 하니까). 그런데 **뜻만 적어 둔 칸도 함께 버려졌다.** 기기에서 '예문 더
// 넣기'로 칸을 만들고 '예문 뜻'에만 적은 뒤 저장했더니, 돌아온 상세에는
// 그 글이 없었고 아무 말도 없었다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_edit_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAssist implements SentenceAssist {
  @override
  int? get remainingToday => 0;
  @override
  int? get dailyLimit => 0;

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
  Future<SentenceSuggestion> suggest(
          {required String language, required String text}) async =>
      const SentenceSuggestion(translation: '', pronunciation: '');
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
  }) async =>
      const WordSuggestion();
}

Future<MyWord> _addWord() async {
  await MyWordStore.add('guest', language: '영어', word: 'huge', example: '첫 예문');
  return (await MyWordStore.loadFor('guest', '영어')).single;
}

Future<void> _openEdit(WidgetTester tester, MyWord word) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: WordEditSheet(
          word: word,
          accountId: 'guest',
          assist: _SilentAssist(),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('뜻만 적힌 칸 찾기', () {
    test('뜻만 있고 예문이 비면 그 번호를 돌려준다', () {
      expect(wordExampleMissingTextAt(['첫', '', ''], ['', '뜻만', '']), 2);
    });

    test('둘 다 비었으면 막지 않는다', () {
      // 칸만 열어 두고 저장해도 괜찮아야 한다.
      expect(wordExampleMissingTextAt(['첫', ''], ['뜻', '']), isNull);
      expect(wordExampleMissingTextAt(['  '], ['   ']), isNull);
    });

    test('예문이 있으면 뜻이 비어도 막지 않는다', () {
      expect(wordExampleMissingTextAt(['첫'], ['']), isNull);
    });

    test('여러 칸이면 처음 것을 짚는다', () {
      expect(wordExampleMissingTextAt(['', ''], ['가', '나']), 1);
    });

    test('짚는 번호가 글귀에 들어간다', () {
      expect(wordExampleNeedsTextMessage(2), contains('예문 2'));
    });
  });

  testWidgets('뜻만 적으면 저장이 막히고 몇 번째인지 알려 준다', (tester) async {
    final word = await _addWord();
    await _openEdit(tester, word);

    // 처음에는 막히지 않는다.
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('edit-word-save')))
            .onPressed,
        isNotNull);

    await tester.tap(find.byKey(const ValueKey('edit-word-example-add')));
    await tester.pumpAndSettle();
    // 빈 칸만 더해도 막히지 않는다.
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('edit-word-save')))
            .onPressed,
        isNotNull);

    await tester.enterText(
        find.byKey(const ValueKey('edit-word-example-meaning-1')), '뜻만 적어 본 줄');
    await tester.pump();

    expect(find.text(wordExampleNeedsTextMessage(2)), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('edit-word-save')))
            .onPressed,
        isNull);

    // 예문을 적으면 다시 풀린다.
    await tester.enterText(
        find.byKey(const ValueKey('edit-word-example-1')), 'A huge wave.');
    await tester.pump();
    expect(find.text(wordExampleNeedsTextMessage(2)), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('edit-word-save')))
            .onPressed,
        isNotNull);
  });
}
