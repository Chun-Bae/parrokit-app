// 고른 낱말의 원형을 짐작한다(5차, 사용자 질문).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/word_base_form.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('복수·3인칭 -s, -es, -ies', () {
    expect(guessBaseForms('projections'), contains('projection'));
    expect(guessBaseForms('boxes'), contains('box'));
    expect(guessBaseForms('studies'), contains('study'));
    // -ss는 자르지 않는다.
    expect(guessBaseForms('class'), isEmpty);
  });

  test('과거 -ed, -ied', () {
    expect(guessBaseForms('worked'), contains('work'));
    expect(guessBaseForms('liked'), contains('like'));
    expect(guessBaseForms('tried'), contains('try'));
    expect(guessBaseForms('stopped'), contains('stop'));
  });

  test('진행형 -ing', () {
    expect(guessBaseForms('working'), contains('work'));
    expect(guessBaseForms('making'), contains('make'));
    expect(guessBaseForms('running'), contains('run'));
  });

  test('짧은 낱말이나 띄어쓴 표현은 짐작하지 않는다', () {
    expect(guessBaseForms('is'), isEmpty);
    expect(guessBaseForms('figure out'), isEmpty);
  });

  test('영어가 아니면 짐작하지 않는다', () {
    expect(canGuessBaseForm('영어'), isTrue);
    expect(canGuessBaseForm('일본어'), isFalse);
  });

  group('단어장에서 같은 단어 찾기', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('같은 낱말이면 그대로 찾는다', () async {
      await MyWordStore.add('guest', language: '영어', word: 'projection');
      final found = await MyWordStore.findSameOrBaseForm('guest',
          language: '영어', word: 'Projection');
      expect(found?.word, 'projection');
    });

    test('다른 꼴이어도 원형으로 찾는다', () async {
      await MyWordStore.add('guest', language: '영어', word: 'projection');
      final found = await MyWordStore.findSameOrBaseForm('guest',
          language: '영어', word: 'projections');
      expect(found?.word, 'projection');
    });

    test('없으면 null, 다른 언어는 짐작하지 않는다', () async {
      expect(
          await MyWordStore.findSameOrBaseForm('guest',
              language: '영어', word: 'nothing'),
          isNull);
      await MyWordStore.add('guest', language: '일본어', word: '読む');
      expect(
          await MyWordStore.findSameOrBaseForm('guest',
              language: '일본어', word: '読みます'),
          isNull);
    });

    test('예문만 더하면 단어는 그대로고 예문이 늘어난다', () async {
      await MyWordStore.add('guest',
          language: '영어', word: 'projection', example: '첫 예문');
      final word = (await MyWordStore.loadFor('guest', '영어')).single;

      final added = await MyWordStore.addExample('guest', word.id,
          const WordExample(text: '두 번째 예문', translation: '뜻'));
      expect(added, isTrue);

      final after = (await MyWordStore.loadFor('guest', '영어')).single;
      expect(after.word, 'projection');
      expect(after.examples.map((e) => e.text), ['첫 예문', '두 번째 예문']);

      // 같은 예문은 또 더하지 않는다.
      expect(
          await MyWordStore.addExample(
              'guest', word.id, const WordExample(text: '두 번째 예문')),
          isFalse);
    });
  });
}
