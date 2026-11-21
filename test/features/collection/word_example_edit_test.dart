// 이미 만든 단어도 예문을 더하거나 고칠 수 있다(5차 338, 사용자 요청).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('예문을 고치면 그 자리만 바뀐다', () async {
    await MyWordStore.add('guest',
        language: '영어', word: 'huge', example: '첫 예문');
    final word = (await MyWordStore.loadFor('guest', '영어')).single;
    await MyWordStore.addExample(
        'guest', word.id, const WordExample(text: '둘째 예문'));

    final ok = await MyWordStore.updateExample('guest', word.id, 0,
        const WordExample(text: '고친 예문', translation: '뜻'));
    expect(ok, isTrue);

    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.examples.map((e) => e.text), ['고친 예문', '둘째 예문']);
    expect(after.examples.first.translation, '뜻');
  });

  test('빈 예문이나 없는 자리는 고치지 않는다', () async {
    await MyWordStore.add('guest',
        language: '영어', word: 'huge', example: '첫 예문');
    final word = (await MyWordStore.loadFor('guest', '영어')).single;

    expect(
        await MyWordStore.updateExample(
            'guest', word.id, 0, const WordExample(text: '   ')),
        isFalse);
    expect(
        await MyWordStore.updateExample(
            'guest', word.id, 3, const WordExample(text: '밖')),
        isFalse);
    expect(
        await MyWordStore.updateExample(
            'guest', '없는-단어', 0, const WordExample(text: '밖')),
        isFalse);

    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.examples.single.text, '첫 예문');
  });

  testWidgets('예문 창은 빈 예문을 막고, 적으면 돌려준다', (tester) async {
    WordExample? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => saved = await showDialog<WordExample>(
              context: context,
              builder: (_) => const WordExampleDialog(word: 'huge'),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('word-example-save')));
    await tester.pumpAndSettle();
    expect(find.text('예문을 적어야 저장할 수 있어요.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('word-example-input')), 'It is huge.');
    await tester.enterText(
        find.byKey(const ValueKey('word-example-translation-input')), '엄청 커요.');
    await tester.tap(find.byKey(const ValueKey('word-example-save')));
    await tester.pumpAndSettle();

    expect(saved?.text, 'It is huge.');
    expect(saved?.translation, '엄청 커요.');
  });

  test('예문을 더하고 고치는 길은 고치기 한 창에 있다(5차 469)', () {
    // 전에는 상세에 '예문 넣기'와 예문마다 고치기·빼기가 따로 있었다.
    // 뜻·발음·유의어까지 한 창에서 손보게 되면서 그 창으로 모았다.
    final detail = File(
            'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(detail, contains("ValueKey('edit-word')"));
    expect(detail, contains("ValueKey('edit-word-example-\$index')"));

    final sheet = File(
            'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    for (final key in [
      "ValueKey('edit-word-meaning-input')",
      "ValueKey('edit-word-pronunciation-input')",
      "ValueKey('edit-word-synonym-add')",
      "ValueKey('edit-word-example-add')",
      "ValueKey('edit-word-save')",
    ]) {
      expect(sheet, contains(key), reason: key);
    }
    expect(sheet, contains('MyWordStore.saveEdits('));
  });

  testWidgets('단어를 처음 만들 때도 예문 뜻을 적을 수 있다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddWordSheet(
          accountId: 'guest',
          language: '영어',
          assist: _SilentAssist(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('word-input')), 'huge');
    await tester.enterText(
        find.byKey(const ValueKey('word-example-0')), 'It is huge.');
    await tester.enterText(
        find.byKey(const ValueKey('word-example-meaning-0')), '엄청 커요.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('save-word')));
    await tester.tap(find.byKey(const ValueKey('save-word')));
    await tester.pumpAndSettle();

    final saved = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(saved.examples.single.text, 'It is huge.');
    expect(saved.examples.single.translation, '엄청 커요.');
  });
}

/// 뜻 채우기를 부르지 않는 가짜(이 테스트는 서버를 쓰지 않는다).
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
  }) async =>
      const WordSuggestion();
}
