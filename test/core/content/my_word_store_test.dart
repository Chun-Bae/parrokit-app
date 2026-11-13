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
  Future<void> remove(String id) async => stored.removeWhere((w) => w.id == id);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MyWordStore.cloud = null;
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
      expect(reviews['a']!.dueAt, day1.add(const Duration(days: 3)));
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
      final due = WordReviewStore.dueWords([w('new'), w('old')], reviews,
          day0.add(const Duration(hours: 1)));
      expect(due.map((e) => e.id), ['old', 'new']);
    });
  });
}
