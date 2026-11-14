import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/word_review_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버 대신 쓰는 가짜. [fail]이면 규칙 배포 전처럼 저장이 실패한다.
class FakeWordCloud implements WordCloud {
  FakeWordCloud({this.fail = false});
  bool fail;
  final List<MyWord> stored = [];

  @override
  Future<List<MyWord>> load(String ownerId) async {
    if (fail) throw Exception('permission-denied');
    return List.of(stored);
  }

  @override
  Future<bool> add(String ownerId, MyWord word) async {
    if (fail) throw Exception('permission-denied');
    if (stored.any((w) =>
        w.language == word.language &&
        w.word.toLowerCase() == word.word.toLowerCase())) {
      return false;
    }
    stored.add(word);
    return true;
  }

  @override
  Future<void> setMeaning(String id, String meaning) async {
    if (fail) throw Exception('permission-denied');
    final index = stored.indexWhere((w) => w.id == id);
    if (index < 0) throw Exception('not-found');
    final before = stored[index];
    stored[index] = MyWord(
      id: before.id,
      language: before.language,
      word: before.word,
      meaning: meaning,
      examples: before.examples,
      topic: before.topic,
      addedAt: before.addedAt,
    );
  }

  @override
  Future<void> remove(String id) async => stored.removeWhere((w) => w.id == id);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MyWordStore.cloud = null;
  });

  group('뜻 나중에 적기', () {
    test('기기에 있는 단어의 뜻을 고친다', () async {
      await MyWordStore.add('guest', language: '영어', word: 'slowly');
      final id = MyWordStore.idFor('영어', 'slowly');
      expect((await MyWordStore.load('guest')).single.meaning, '');

      expect(await MyWordStore.setMeaning('guest', id, ' 천천히 '), isTrue);
      expect((await MyWordStore.load('guest')).single.meaning, '천천히');
    });

    test('뜻을 고쳐도 예문과 추가한 날은 그대로 둔다', () async {
      await MyWordStore.add('guest',
          language: '영어',
          word: 'slowly',
          example: 'Could you speak more slowly?',
          exampleTranslation: '조금 더 천천히 말씀해 주실 수 있나요?');
      final id = MyWordStore.idFor('영어', 'slowly');
      final before = (await MyWordStore.load('guest')).single;

      await MyWordStore.setMeaning('guest', id, '천천히');
      final after = (await MyWordStore.load('guest')).single;
      expect(after.meaning, '천천히');
      expect(after.examples.single.text, before.examples.single.text);
      expect(after.examples.single.translation,
          before.examples.single.translation);
      expect(after.addedAt, before.addedAt);
    });

    test('규칙 길이를 넘는 뜻은 줄여서 저장한다', () async {
      await MyWordStore.add('guest', language: '영어', word: 'slowly');
      final id = MyWordStore.idFor('영어', 'slowly');

      await MyWordStore.setMeaning('guest', id, '가' * (meaningMaxLength + 50));
      expect((await MyWordStore.load('guest')).single.meaning.length,
          meaningMaxLength);
    });

    test('없는 단어면 고치지 않고 false', () async {
      expect(await MyWordStore.setMeaning('guest', 'no-such-id', '뜻'), isFalse);
    });
  });

  group('게스트(기기 저장)', () {
    test('추가하고 언어별로 읽고 지운다', () async {
      expect(
          await MyWordStore.add('guest',
              language: '영어', word: ' figure out ', meaning: '알아내다'),
          WordAddResult.added);
      await MyWordStore.add('guest', language: '일본어', word: '食べる');
      final en = await MyWordStore.loadFor('guest', '영어');
      expect(en.map((w) => w.word), ['figure out']);
      expect(en.single.meaning, '알아내다');
      await MyWordStore.remove('guest', en.single.id);
      expect(await MyWordStore.loadFor('guest', '영어'), isEmpty);
      expect(await MyWordStore.loadFor('guest', '일본어'), hasLength(1));
    });

    test('같은 언어의 같은 단어는 대소문자와 공백을 무시하고 한 번만', () async {
      await MyWordStore.add('guest', language: '영어', word: 'Hesitate');
      expect(await MyWordStore.add('guest', language: '영어', word: ' hesitate'),
          WordAddResult.duplicate);
      expect(await MyWordStore.add('guest', language: '일본어', word: 'hesitate'),
          WordAddResult.added);
    });

    test('문장에서 저장하면 예문과 원래 문장 id를 함께 둔다', () async {
      await MyWordStore.add('guest',
          language: '영어',
          word: 'supposed to',
          example: "I'm supposed to meet her at six.",
          sourceSentenceId: 'default-12');
      final w = (await MyWordStore.load('guest')).single;
      expect(w.example, "I'm supposed to meet her at six.");
      expect(w.sourceSentenceId, 'default-12');
    });
  });

  group('로그인(서버 저장)', () {
    test('서버에 저장하고 서버에서 읽는다', () async {
      final cloud = FakeWordCloud();
      MyWordStore.cloud = cloud;
      expect(await MyWordStore.add('uid1', language: '영어', word: 'nuance'),
          WordAddResult.added);
      expect(cloud.stored.map((w) => w.word), ['nuance']);
      expect((await MyWordStore.load('uid1')).map((w) => w.word), ['nuance']);
    });

    test('서버 저장이 실패하면 기기에 남기고 목록에는 보인다', () async {
      final cloud = FakeWordCloud(fail: true);
      MyWordStore.cloud = cloud;
      expect(await MyWordStore.add('uid1', language: '영어', word: 'nuance'),
          WordAddResult.savedOnDevice);
      expect((await MyWordStore.load('uid1')).map((w) => w.word), ['nuance']);
      // 서버가 살아나도 기기에 남은 단어는 같이 보이고 겹치지 않는다.
      cloud.fail = false;
      await MyWordStore.add('uid1', language: '영어', word: 'subtle');
      expect((await MyWordStore.load('uid1')).map((w) => w.word),
          containsAll(['nuance', 'subtle']));
    });
  });

  group('예문 여러 개', () {
    test('예문을 여러 개 저장하고 순서대로 읽는다', () async {
      await MyWordStore.add('guest',
          language: '영어',
          word: 'figure out',
          examples: const [
            WordExample(text: "I'll figure it out.", translation: '내가 알아낼게.'),
            WordExample(text: 'Did you figure out the password?'),
          ]);
      final w = (await MyWordStore.load('guest')).single;
      expect(w.examples.map((e) => e.text),
          ["I'll figure it out.", 'Did you figure out the password?']);
      expect(w.examples.first.translation, '내가 알아낼게.');
      // 첫 예문은 예전 이름으로도 읽힌다.
      expect(w.example, "I'll figure it out.");
      expect(w.exampleTranslation, '내가 알아낼게.');
    });

    test('빈 예문은 버리고 다섯 개까지만 둔다', () {
      final clipped = clipWordExamples([
        const WordExample(text: ' '),
        for (var i = 0; i < 7; i++) WordExample(text: '예문 $i'),
      ]);
      expect(clipped, hasLength(examplesMaxCount));
      expect(clipped.first.text, '예문 0');
    });

    test('예전 형식(예문 하나)으로 저장된 단어도 읽는다', () {
      final w = MyWord.fromJson({
        'id': 'en:old',
        'language': '영어',
        'word': 'old',
        'example': 'An old sentence.',
        'exampleTranslation': '예전 문장.',
        'sourceSentenceId': 's1',
      })!;
      expect(w.examples, hasLength(1));
      expect(w.examples.single.text, 'An old sentence.');
      expect(w.examples.single.translation, '예전 문장.');
      expect(w.sourceSentenceId, 's1');
    });

    test('예문이 없으면 빈 목록이다', () {
      final w = MyWord.fromJson(
          {'id': 'en:x', 'language': '영어', 'word': 'x'})!;
      expect(w.examples, isEmpty);
      expect(w.example, '');
    });

    test('저장했다 읽어도 예문이 그대로다', () {
      final w = MyWord(
        id: 'en:keep',
        language: '영어',
        word: 'keep',
        examples: const [
          WordExample(text: 'Keep going.', translation: '계속 가.'),
          WordExample(text: 'Keep it simple.'),
        ],
      );
      final back = MyWord.fromJson(w.toJson())!;
      expect(back.examples, w.examples);
    });

    test('서버에도 예문 목록과 첫 예문을 함께 올린다', () async {
      final cloud = FakeWordCloud();
      MyWordStore.cloud = cloud;
      await MyWordStore.add('uid1',
          language: '영어',
          word: 'nuance',
          examples: const [
            WordExample(text: 'A subtle nuance.'),
            WordExample(text: 'Nuance matters.'),
          ]);
      final stored = cloud.stored.single;
      expect(stored.examples.map((e) => e.text),
          ['A subtle nuance.', 'Nuance matters.']);
      expect(stored.example, 'A subtle nuance.');
    });
  });

  group('서버 규칙 길이', () {
    test('긴 문장에서 저장해도 예문·번역을 규칙 길이 안으로 줄여 서버에 올린다',
        () async {
      final cloud = FakeWordCloud();
      MyWordStore.cloud = cloud;
      final longSentence = 'word ' * 100; // 500자
      final longTranslation = '번역 ' * 200; // 600자
      expect(
        await MyWordStore.add('uid1',
            language: '영어',
            word: 'word',
            meaning: '뜻' * 250,
            example: longSentence,
            exampleTranslation: longTranslation,
            topic: '주제' * 30),
        WordAddResult.added,
      );
      final w = cloud.stored.single;
      expect(w.example.length, lessThanOrEqualTo(exampleMaxLength));
      expect(w.exampleTranslation.length, lessThanOrEqualTo(exampleMaxLength));
      expect(w.meaning.length, meaningMaxLength);
      expect(w.topic.length, topicMaxLength);
      expect(longSentence.trim().startsWith(w.example), isTrue);
    });

    test('짧은 값은 그대로 둔다', () {
      expect(clipToLength('nuance', wordMaxLength), 'nuance');
      expect(clipToLength('', exampleMaxLength), '');
    });

    test('두 칸짜리 글자(이모지)를 반으로 자르지 않는다', () {
      final clipped = clipToLength('a😀😀', 4);
      expect(clipped, 'a😀');
      expect(clipped.length, 3);
    });
  });

  group('복습', () {
    final day0 = DateTime(2026, 11, 13, 9);
    MyWord w(String id) => MyWord(id: id, language: '영어', word: id);

    test('새 단어는 바로, 알아요를 누르면 1·3·7일 뒤에 다시 나온다', () async {
      final words = [w('a')];
      expect(WordReviewStore.dueWords(words, {}, day0), hasLength(1));
      await WordReviewStore.record('guest', 'a', known: true, now: day0);
      var reviews = await WordReviewStore.loadAll('guest');
      expect(WordReviewStore.dueWords(words, reviews, day0), isEmpty);
      final day1 = day0.add(const Duration(days: 1));
      expect(WordReviewStore.dueWords(words, reviews, day1), hasLength(1));
      await WordReviewStore.record('guest', 'a', known: true, now: day1);
      reviews = await WordReviewStore.loadAll('guest');
      // 3일 뒤 그날 0시(11/14 9시 → 11/17 0시).
      expect(reviews['a']!.dueAt, DateTime(2026, 11, 17));
    });

    test('밤늦게 알아요를 눌러도 다음 날 아침이면 나온다', () async {
      final late = DateTime(2026, 11, 13, 23, 30);
      await WordReviewStore.record('guest', 'a', known: true, now: late);
      final reviews = await WordReviewStore.loadAll('guest');
      expect(
          WordReviewStore.dueWords(
              [w('a')], reviews, DateTime(2026, 11, 13, 23, 59)),
          isEmpty);
      expect(
          WordReviewStore.dueWords(
              [w('a')], reviews, DateTime(2026, 11, 14, 8)),
          hasLength(1));
    });

    test('간격은 1·3·7·14·30일이고 그 뒤로는 30일씩', () async {
      var at = DateTime(2026, 1, 1, 12);
      final gaps = <int>[];
      for (var i = 0; i < 7; i++) {
        final r =
            await WordReviewStore.record('guest', 'a', known: true, now: at);
        gaps.add(
            r.dueAt!.difference(DateTime(at.year, at.month, at.day)).inDays);
        at = r.dueAt!.add(const Duration(hours: 9));
      }
      expect(gaps, [1, 3, 7, 14, 30, 30, 30]);
    });

    test('달·해가 바뀌어도 날짜로 센다', () {
      expect(WordReviewStore.dueDayAfter(DateTime(2026, 12, 31, 22), 1),
          DateTime(2027, 1, 1));
      expect(WordReviewStore.dueDayAfter(DateTime(2026, 1, 31, 8), 30),
          DateTime(2026, 3, 2));
    });

    test('다시를 누르면 처음 단계로 돌아가 오늘 다시 나온다', () async {
      await WordReviewStore.record('guest', 'a', known: true, now: day0);
      await WordReviewStore.record('guest', 'a', known: false, now: day0);
      final reviews = await WordReviewStore.loadAll('guest');
      expect(reviews['a']!.step, 0);
      expect(WordReviewStore.dueWords([w('a')], reviews, day0), hasLength(1));
    });

    test('기한이 지난 단어가 새 단어보다 먼저 나온다', () async {
      await WordReviewStore.record('guest', 'old', known: false, now: day0);
      final reviews = await WordReviewStore.loadAll('guest');
      final due = WordReviewStore.dueWords(
          [w('new'), w('old')], reviews, day0.add(const Duration(hours: 1)));
      expect(due.map((e) => e.id), ['old', 'new']);
    });
  });
}
