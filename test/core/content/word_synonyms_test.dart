// 단어장 유의어 칸(5차, 사용자 요청). 나중에 생긴 칸이라 예전에 저장한
// 단어에는 없다. 없으면 빈 목록으로 읽어야 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MyWordStore.cloud = null;
  });

  group('적은 한 줄을 목록으로', () {
    test('쉼표·가운뎃점·빗금으로 나누고 앞뒤 공백을 턴다', () {
      expect(parseSynonymInput('big, large · huge/ enormous'),
          ['big', 'large', 'huge', 'enormous']);
    });

    test('빈 것과 겹치는 것은 버린다', () {
      expect(parseSynonymInput('big, , big ,, large'), ['big', 'large']);
      expect(parseSynonymInput('   '), isEmpty);
    });

    test('개수와 길이를 한도 안으로 줄인다', () {
      final many = parseSynonymInput(
          List.generate(synonymsMaxCount + 5, (i) => 'w$i').join(','));
      expect(many.length, synonymsMaxCount);

      final long = parseSynonymInput('a' * (synonymMaxLength + 10));
      expect(long.single.length, synonymMaxLength);
    });

    test('목록을 다시 한 줄로 되돌린다', () {
      expect(synonymInputText(['big', 'large']), 'big, large');
    });
  });

  group('저장과 읽기', () {
    test('저장한 유의어가 그대로 돌아온다', () async {
      await MyWordStore.add('guest',
          language: '영어',
          word: 'huge',
          meaning: '거대한',
          synonyms: ['big', 'large']);

      final saved = (await MyWordStore.load('guest')).single;
      expect(saved.synonyms, ['big', 'large']);
    });

    test('예전에 저장한 단어(유의어 칸이 없는 것)도 그대로 읽힌다', () {
      // 5차 전 형식: synonyms 자체가 없다.
      final old = MyWord.fromJson({
        'id': 'en|slowly',
        'language': '영어',
        'word': 'slowly',
        'meaning': '천천히',
        'example': 'Speak slowly.',
      });

      expect(old, isNotNull);
      expect(old!.synonyms, isEmpty);
      expect(old.meaning, '천천히');
      expect(old.example, 'Speak slowly.');
    });

    test('읽고 다시 적어도 유의어가 살아 있다', () {
      final word = MyWord(
        id: 'en|huge',
        language: '영어',
        word: 'huge',
        synonyms: ['big', 'large'],
      );
      final again = MyWord.fromJson(word.toJson());
      expect(again!.synonyms, ['big', 'large']);
    });

    test('이상한 값이 섞여 있어도 글자만 남긴다', () {
      final word = MyWord.fromJson({
        'id': 'en|huge',
        'language': '영어',
        'word': 'huge',
        'synonyms': ['big', 3, null, '  ', 'large'],
      });
      expect(word!.synonyms, ['big', 'large']);
    });
  });

  group('나중에 고치기', () {
    test('기기에 있는 단어의 유의어를 고친다', () async {
      await MyWordStore.add('guest', language: '영어', word: 'huge');
      final id = MyWordStore.idFor('영어', 'huge');

      expect(await MyWordStore.setSynonyms('guest', id, ['big', 'large']),
          isTrue);
      expect((await MyWordStore.load('guest')).single.synonyms,
          ['big', 'large']);

      // 다시 비우면 지워진다.
      expect(await MyWordStore.setSynonyms('guest', id, []), isTrue);
      expect((await MyWordStore.load('guest')).single.synonyms, isEmpty);
    });

    test('뜻을 고쳐도 유의어가 지워지지 않는다', () async {
      await MyWordStore.add('guest',
          language: '영어', word: 'huge', synonyms: ['big']);
      final id = MyWordStore.idFor('영어', 'huge');

      await MyWordStore.setMeaning('guest', id, '거대한');

      final saved = (await MyWordStore.load('guest')).single;
      expect(saved.meaning, '거대한');
      expect(saved.synonyms, ['big'], reason: '뜻만 고치는 것이다');
    });

    test('고칠 때도 길이와 개수를 줄인다', () async {
      await MyWordStore.add('guest', language: '영어', word: 'huge');
      final id = MyWordStore.idFor('영어', 'huge');

      await MyWordStore.setSynonyms(
          'guest', id, List.generate(synonymsMaxCount + 3, (i) => 'w$i'));
      expect((await MyWordStore.load('guest')).single.synonyms.length,
          synonymsMaxCount);
    });
  });
}
