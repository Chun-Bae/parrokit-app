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
      synonyms: before.synonyms,
      topic: before.topic,
      addedAt: before.addedAt,
    );
  }

  @override
  Future<void> setExamples(String id, List<WordExample> examples) async {
    if (fail) throw Exception('permission-denied');
    final index = stored.indexWhere((w) => w.id == id);
    if (index < 0) throw Exception('not-found');
    final before = stored[index];
    stored[index] = MyWord(
      id: before.id,
      language: before.language,
      word: before.word,
      meaning: before.meaning,
      examples: examples,
      synonyms: before.synonyms,
      topic: before.topic,
      addedAt: before.addedAt,
    );
  }

  @override
  Future<void> setSynonyms(String id, List<String> synonyms) async {
    if (fail) throw Exception('permission-denied');
    final index = stored.indexWhere((w) => w.id == id);
    if (index < 0) throw Exception('not-found');
    final before = stored[index];
    stored[index] = MyWord(
      id: before.id,
      language: before.language,
      word: before.word,
      meaning: before.meaning,
      examples: before.examples,
      synonyms: synonyms,
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

  group('로그인 사용자의 예문 더하기·빼기(5차 330)', () {
    late FakeWordCloud cloud;

    setUp(() {
      cloud = FakeWordCloud();
      MyWordStore.cloud = cloud;
    });

    Future<String> seed() async {
      await MyWordStore.add('uid1',
          language: '영어', word: 'projection', example: '첫 예문');
      return cloud.stored.single.id;
    }

    test('서버 단어에 예문을 더한다', () async {
      final id = await seed();
      expect(
          await MyWordStore.addExample(
              'uid1', id, const WordExample(text: '두 번째 예문')),
          isTrue);
      expect(cloud.stored.single.examples.map((e) => e.text),
          ['첫 예문', '두 번째 예문']);
    });

    test('서버 단어의 예문을 뺀다', () async {
      final id = await seed();
      await MyWordStore.addExample(
          'uid1', id, const WordExample(text: '두 번째 예문'));
      expect(await MyWordStore.removeExample('uid1', id, 0), isTrue);
      expect(cloud.stored.single.examples.map((e) => e.text), ['두 번째 예문']);
    });

    test('서버가 막히면 거짓을 돌려주고 그대로 둔다', () async {
      final id = await seed();
      cloud.fail = true;
      expect(
          await MyWordStore.addExample(
              'uid1', id, const WordExample(text: '안 들어감')),
          isFalse);
      cloud.fail = false;
      expect(cloud.stored.single.examples.map((e) => e.text), ['첫 예문']);
    });

    test('어형이 다른 단어도 서버 목록에서 찾는다', () async {
      await seed();
      final found = await MyWordStore.findRelatedWords('uid1',
          language: '영어', word: 'projections');
      expect(found.map((w) => w.word), ['projection']);
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
      await WordReviewStore.record('guest', 'a', rating: ReviewRating.known, now: day0);
      var reviews = await WordReviewStore.loadAll('guest');
      expect(WordReviewStore.dueWords(words, reviews, day0), isEmpty);
      final day1 = day0.add(const Duration(days: 1));
      expect(WordReviewStore.dueWords(words, reviews, day1), hasLength(1));
      await WordReviewStore.record('guest', 'a', rating: ReviewRating.known, now: day1);
      reviews = await WordReviewStore.loadAll('guest');
      // 3일 뒤 그날 0시(11/14 9시 → 11/17 0시).
      expect(reviews['a']!.dueAt, DateTime(2026, 11, 17));
    });

    test('밀린 것끼리는 오래 밀린 단어가 먼저 나온다', () async {
      // '기한 지난 것 vs 새 단어'는 아래에서 지키는데, 밀린 것끼리의 차례는
      // 주석으로만 적혀 있었다(5차 점검).
      await WordReviewStore.record('guest', 'old',
          rating: ReviewRating.known,
          now: day0.subtract(const Duration(days: 10)));
      await WordReviewStore.record('guest', 'recent',
          rating: ReviewRating.known,
          now: day0.subtract(const Duration(days: 2)));
      final reviews = await WordReviewStore.loadAll('guest');

      final order =
          WordReviewStore.dueWords([w('recent'), w('old')], reviews, day0);

      expect(order.map((e) => e.id).toList(), ['old', 'recent']);
    });

    test('밤늦게 알아요를 눌러도 다음 날 아침이면 나온다', () async {
      final late = DateTime(2026, 11, 13, 23, 30);
      await WordReviewStore.record('guest', 'a', rating: ReviewRating.known, now: late);
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

    test('알아요만 누르면 간격이 1·3일로 시작해 2.5배씩 벌어진다', () async {
      var at = DateTime(2026, 1, 1, 12);
      final gaps = <int>[];
      for (var i = 0; i < 6; i++) {
        final r = await WordReviewStore.record('guest', 'a',
            rating: ReviewRating.known, now: at);
        gaps.add(
            r.dueAt!.difference(DateTime(at.year, at.month, at.day)).inDays);
        at = r.dueAt!.add(const Duration(hours: 9));
      }
      // 1, 3, 3×2.5=8, 8×2.5=20, 50, 125. 예전 고정 표(최대 30일)보다 멀리 간다.
      expect(gaps, [1, 3, 8, 20, 50, 125]);
    });

    test('쉬워요는 더 멀리, 다시는 쉬움 계수를 깎는다', () async {
      var at = DateTime(2026, 1, 1, 12);
      for (var i = 0; i < 2; i++) {
        final r = await WordReviewStore.record('guest', 'a',
            rating: ReviewRating.known, now: at);
        at = r.dueAt!.add(const Duration(hours: 9));
      }
      final easy = await WordReviewStore.record('guest', 'a',
          rating: ReviewRating.easy, now: at);
      // 3일 × (2.5+0.15) × 1.3 = 10일. 알아요였다면 8일이다.
      expect(easy.dueAt!.difference(DateTime(at.year, at.month, at.day)).inDays,
          10);
      expect(easy.ease, closeTo(2.65, 0.001));

      final again = await WordReviewStore.record('guest', 'a',
          rating: ReviewRating.again, now: at);
      expect(again.ease, closeTo(2.45, 0.001), reason: '틀리면 계수가 깎인다');
      expect(again.step, 0);
    });

    test('쉬움 계수는 1.3 아래로 내려가지 않는다', () {
      var ease = 2.5;
      for (var i = 0; i < 20; i++) {
        ease = WordReviewStore.nextEase(ease, ReviewRating.again);
      }
      expect(ease, WordReviewStore.minEase);
    });

    test('간격은 1년에서 멈춘다', () {
      expect(
          WordReviewStore.nextInterval(
              interval: 300, step: 9, ease: 2.5, rating: ReviewRating.known),
          WordReviewStore.maxInterval);
    });

    test('예전 기록(단계만 있는 것)은 쓰던 간격을 그대로 이어받는다', () async {
      // step 3까지 간 예전 사용자: 그때 간격은 7일이었다.
      const old = WordReview(step: 3);
      expect(old.intervalOrFromStep, 7);
      expect(old.easeOrDefault, WordReviewStore.defaultEase);
      expect(
          WordReviewStore.nextInterval(
              interval: old.intervalOrFromStep,
              step: old.step,
              ease: old.easeOrDefault,
              rating: ReviewRating.known),
          18,
          reason: '7 × 2.5 = 17.5 → 18일');
    });

    test('달·해가 바뀌어도 날짜로 센다', () {
      expect(WordReviewStore.dueDayAfter(DateTime(2026, 12, 31, 22), 1),
          DateTime(2027, 1, 1));
      expect(WordReviewStore.dueDayAfter(DateTime(2026, 1, 31, 8), 30),
          DateTime(2026, 3, 2));
    });

    test('다시를 누르면 처음 단계로 돌아가 오늘 다시 나온다', () async {
      await WordReviewStore.record('guest', 'a', rating: ReviewRating.known, now: day0);
      await WordReviewStore.record('guest', 'a', rating: ReviewRating.again, now: day0);
      final reviews = await WordReviewStore.loadAll('guest');
      expect(reviews['a']!.step, 0);
      expect(WordReviewStore.dueWords([w('a')], reviews, day0), hasLength(1));
    });

    test('기한이 지난 단어가 새 단어보다 먼저 나온다', () async {
      await WordReviewStore.record('guest', 'old', rating: ReviewRating.again, now: day0);
      final reviews = await WordReviewStore.loadAll('guest');
      final due = WordReviewStore.dueWords(
          [w('new'), w('old')], reviews, day0.add(const Duration(hours: 1)));
      expect(due.map((e) => e.id), ['old', 'new']);
    });

    test('이 답을 고르면 며칠 뒤에 나오는지 미리 알려 준다', () {
      const fresh = WordReview();
      expect(WordReviewStore.previewInterval(fresh, ReviewRating.known), 1);
      expect(WordReviewStore.previewInterval(fresh, ReviewRating.again), 0);
      // 처음부터 쉬운 단어는 바로 4일 뒤로 민다(1일 × 1.3은 또 1일이라 뜻이 없다).
      expect(WordReviewStore.previewInterval(fresh, ReviewRating.easy), 4);

      // 3일 간격까지 온 단어: 알아요 8일, 쉬워요 10일.
      const third = WordReview(step: 2, intervalDays: 3, ease: 2.5);
      expect(WordReviewStore.previewInterval(third, ReviewRating.known), 8);
      expect(WordReviewStore.previewInterval(third, ReviewRating.easy), 10);
    });

    test('며칠 뒤인지 적는 말', () {
      expect(WordReviewStore.intervalLabel(0), '오늘');
      expect(WordReviewStore.intervalLabel(1), '내일');
      expect(WordReviewStore.intervalLabel(8), '8일 뒤');
    });

    test('기한까지 남은 날도 같은 말로 적고, 지난 것은 오늘로 본다', () {
      final now = DateTime(2026, 11, 15, 9);
      expect(WordReviewStore.dueLabel(DateTime(2026, 11, 15), now), '오늘');
      expect(WordReviewStore.dueLabel(DateTime(2026, 11, 16), now), '내일');
      expect(WordReviewStore.dueLabel(DateTime(2026, 11, 23), now), '8일 뒤');
      expect(WordReviewStore.dueLabel(DateTime(2026, 11, 1), now), '오늘',
          reason: '기한이 지난 단어는 오늘 볼 단어다');
      expect(WordReviewStore.dueLabel(null, now), '오늘', reason: '새 단어');
    });

    test('목록은 언제 다시 보는지 적는다', () {
      // 전에는 '오늘'만 적혀 무엇의 오늘인지 몰랐다(5차).
      final now = DateTime(2026, 11, 15, 23);
      expect(WordReviewStore.nextSeenLabel(DateTime(2026, 11, 15), now),
          '오늘 다시');
      expect(WordReviewStore.nextSeenLabel(DateTime(2026, 11, 16), now),
          '내일 다시');
      expect(WordReviewStore.nextSeenLabel(DateTime(2026, 11, 23), now),
          '8일 뒤 다시');
      expect(WordReviewStore.nextSeenLabel(null, now), '오늘 다시',
          reason: '새 단어');
    });
  });
}
