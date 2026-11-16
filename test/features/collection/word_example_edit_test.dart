// 이미 만든 단어도 예문을 더하거나 고칠 수 있다(5차 338, 사용자 요청).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
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

  test('단어 상세에 예문 더하기와 고치기가 있다', () {
    final code = File(
            'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains("ValueKey('add-word-example')"));
    expect(code, contains("ValueKey('edit-word-example-\$index')"));
    expect(code, contains('MyWordStore.updateExample('));
  });
}
