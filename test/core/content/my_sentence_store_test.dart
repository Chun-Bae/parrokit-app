import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('adds, dedupes, filters by language and removes', () async {
    expect(
      await MySentenceStore.add('a', language: '영어', text: ' Nice to meet you '),
      isTrue,
    );
    expect(
      await MySentenceStore.add('a', language: '영어', text: 'Nice to meet you'),
      isFalse,
    );
    await MySentenceStore.add('a', language: '일본어', text: 'ありがとう');

    final english = await MySentenceStore.loadFor('a', '영어');
    expect(english.map((s) => s.text), ['Nice to meet you']);
    expect(await MySentenceStore.load('b'), isEmpty);

    await MySentenceStore.remove('a', english.single.id);
    expect(await MySentenceStore.loadFor('a', '영어'), isEmpty);
  });

  test('add bumps revision so the parrot reloads', () async {
    final before = SentenceActivityStore.revision.value;
    await MySentenceStore.add('a', language: '영어', text: 'See you soon');
    expect(SentenceActivityStore.revision.value, before + 1);
  });

  test('ignores empty text and corrupt data', () async {
    expect(await MySentenceStore.add('a', language: '영어', text: '  '), isFalse);
    SharedPreferences.setMockInitialValues(
        {'parrokit.my_sentences.v1.a': 'not json'});
    expect(await MySentenceStore.load('a'), isEmpty);
  });
}
