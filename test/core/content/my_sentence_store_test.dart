import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_cloud_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('adds, dedupes, filters by language and removes', () async {
    expect(
      await MySentenceStore.add('a',
          language: '영어', text: ' Nice to meet you '),
      isTrue,
    );
    expect(
      await MySentenceStore.add('a', language: '영어', text: 'Nice to meet you'),
      isFalse,
    );
    await MySentenceStore.add('a', language: '일본어', text: 'ありがとう');

    final english = await MySentenceStore.loadFor('a', '영어');
    expect(english.map((s) => s.text), ['Nice to meet you']);
    expect(english.single.addedAt, isNotNull);
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

  test('닉네임을 함께 저장하고 없으면 빈 값이다', () async {
    await MySentenceStore.add('a',
        language: '영어', text: 'With author', author: ' 앵무 ');
    await MySentenceStore.add('a', language: '영어', text: 'No author');
    final all = await MySentenceStore.loadFor('a', '영어');
    expect(all.firstWhere((s) => s.text == 'With author').author, '앵무');
    expect(all.firstWhere((s) => s.text == 'No author').author, isEmpty);
  });

  group('로그인한 사용자는 서버에 저장한다', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      MySentenceStore.cloud = SentenceCloudStore(firestore: firestore);
    });
    tearDown(() => MySentenceStore.cloud = null);

    test('추가하면 나만 보는 문서가 생기고 내가 원작자다', () async {
      expect(
        await MySentenceStore.add('u1',
            language: '영어', text: ' Nice to meet you ', author: '앵무'),
        isTrue,
      );
      final docs = (await firestore.collection('sentences').get()).docs;
      expect(docs, hasLength(1));
      final data = docs.single.data();
      expect(docs.single.id, startsWith('my-'));
      expect(data['ownerId'], 'u1');
      expect(data['authorId'], 'u1');
      expect(data['authorName'], '앵무');
      expect(data['visibility'], 'private');
      expect(data['likeCount'], 0);
      expect(data['text'], 'Nice to meet you');
      expect(data.containsKey('sourceSharedId'), isFalse);

      final mine = await MySentenceStore.load('u1');
      expect(mine.single.id, docs.single.id);
      expect(mine.single.authorId, 'u1');
      expect(mine.single.addedAt, isNotNull);
    });

    test('같은 언어의 같은 문장은 한 번만 들어가고 다른 계정은 서로 안 보인다', () async {
      await MySentenceStore.add('u1', language: '영어', text: 'See you');
      expect(
        await MySentenceStore.add('u1', language: '영어', text: ' See you '),
        isFalse,
      );
      expect(
        await MySentenceStore.add('u1', language: '일본어', text: 'See you'),
        isTrue,
      );
      expect(await MySentenceStore.add('u2', language: '영어', text: 'See you'),
          isTrue);
      expect(await MySentenceStore.load('u1'), hasLength(2));
      expect(await MySentenceStore.loadFor('u1', '영어'), hasLength(1));
      expect(await MySentenceStore.load('u2'), hasLength(1));
    });

    test('남의 공개 문장을 저장하면 원작자를 남기고 나만 보는 사본이 된다', () async {
      await firestore.collection('sentences').doc('my-원본').set({
        'ownerId': 'mina',
        'authorId': 'mina',
        'authorName': 'Mina',
        'language': '영어',
        'text': 'Could I get this to go?',
        'visibility': 'public',
        'likeCount': 3,
      });
      await MySentenceStore.add('u1',
          language: '영어',
          text: 'Could I get this to go?',
          author: 'Mina',
          authorId: 'mina',
          sourceSharedId: 'my-원본');

      final copy = (await MySentenceStore.load('u1')).single;
      expect(copy.id, isNot('my-원본'));
      expect(copy.author, 'Mina');
      expect(copy.authorId, 'mina');
      expect(copy.sourceSharedId, 'my-원본');
      final data =
          (await firestore.collection('sentences').doc(copy.id).get()).data()!;
      expect(data['ownerId'], 'u1');
      expect(data['visibility'], 'private');
      expect(data['likeCount'], 0);
      // 원본은 그대로다.
      expect(
          (await firestore.collection('sentences').doc('my-원본').get())
              .data()!['likeCount'],
          3);
    });

    test('지우면 문서가 사라지고, 추가와 삭제는 앵무새가 다시 읽도록 신호를 올린다', () async {
      final before = SentenceActivityStore.revision.value;
      await MySentenceStore.add('u1', language: '영어', text: 'Bye');
      final added = await MySentenceStore.findByText('u1', '영어', ' Bye ');
      expect(added, isNotNull);
      expect(await MySentenceStore.findByText('u1', '일본어', 'Bye'), isNull);
      await MySentenceStore.remove('u1', added!.id);
      expect(await MySentenceStore.load('u1'), isEmpty);
      expect((await firestore.collection('sentences').get()).docs, isEmpty);
      expect(SentenceActivityStore.revision.value, before + 2);
    });

    test('게스트는 서버를 쓰지 않고 이 기기에 저장한다', () async {
      await MySentenceStore.add('guest', language: '영어', text: 'Local only');
      expect((await firestore.collection('sentences').get()).docs, isEmpty);
      expect(await MySentenceStore.load('guest'), hasLength(1));
    });
  });
}
