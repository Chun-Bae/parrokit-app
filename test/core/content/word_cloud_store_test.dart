import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/word_cloud_store.dart';

MyWord _word(String word,
        {String language = 'en',
        String meaning = '',
        String example = '',
        String sourceSentenceId = '',
        String topic = '내 단어'}) =>
    MyWord(
      id: 'local-$word',
      language: language,
      word: word,
      meaning: meaning,
      example: example,
      sourceSentenceId: sourceSentenceId,
      topic: topic,
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreWordCloud cloud;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    cloud = FirestoreWordCloud(firestore: firestore);
  });

  test('저장한 단어를 같은 주인으로 다시 읽는다', () async {
    final added = await cloud.add(
        'u1',
        _word('figure out',
            meaning: '알아내다',
            example: 'I will figure it out.',
            sourceSentenceId: 's1',
            topic: '일상'));
    expect(added, isTrue);

    final words = await cloud.load('u1');
    expect(words, hasLength(1));
    final w = words.single;
    expect(w.word, 'figure out');
    expect(w.language, 'en');
    expect(w.meaning, '알아내다');
    expect(w.example, 'I will figure it out.');
    expect(w.sourceSentenceId, 's1');
    expect(w.topic, '일상');
    // id는 Firestore 문서 id다(지울 때 이 id를 쓴다).
    expect(w.id, isNot('local-figure out'));
    expect(w.addedAt, isNotNull);
  });

  test('같은 언어에 대소문자·공백만 다른 단어는 다시 넣지 않는다', () async {
    expect(await cloud.add('u1', _word('Hello')), isTrue);
    expect(await cloud.add('u1', _word(' hello ')), isFalse);
    expect(await cloud.load('u1'), hasLength(1));
  });

  test('언어가 다르거나 주인이 다르면 같은 단어도 넣는다', () async {
    expect(await cloud.add('u1', _word('pan', language: 'en')), isTrue);
    expect(await cloud.add('u1', _word('pan', language: 'es')), isTrue);
    expect(await cloud.add('u2', _word('pan', language: 'en')), isTrue);
    expect(await cloud.load('u1'), hasLength(2));
    expect(await cloud.load('u2'), hasLength(1));
  });

  test('다른 사람의 단어는 읽지 않는다', () async {
    await cloud.add('u2', _word('secret'));
    expect(await cloud.load('u1'), isEmpty);
  });

  test('지우면 다시 읽을 때 없다', () async {
    await cloud.add('u1', _word('keep'));
    await cloud.add('u1', _word('drop'));
    final drop = (await cloud.load('u1')).firstWhere((w) => w.word == 'drop');
    await cloud.remove(drop.id);
    final left = await cloud.load('u1');
    expect(left.map((w) => w.word), ['keep']);
  });

  test('저장한 문서는 firestore.rules validWord가 검사하는 필드와 createdAt을 갖는다', () async {
    await cloud.add('u1', _word('word', meaning: '뜻'));
    final docs =
        (await firestore.collection(FirestoreWordCloud.collection).get()).docs;
    expect(docs, hasLength(1));
    expect(
      docs.single.data().keys.toSet(),
      {
        'ownerId',
        'language',
        'word',
        'meaning',
        'example',
        'exampleTranslation',
        'sourceSentenceId',
        'topic',
        'createdAt',
      },
    );
    expect(docs.single.data()['ownerId'], 'u1');
  });

  test('예전 문서에 빠진 필드가 있어도 기본값으로 읽는다', () async {
    await firestore
        .collection(FirestoreWordCloud.collection)
        .add({'ownerId': 'u1', 'word': 'old'});
    final w = (await cloud.load('u1')).single;
    expect(w.word, 'old');
    expect(w.language, '');
    expect(w.meaning, '');
    expect(w.topic, '내 단어');
    expect(w.addedAt, isNotNull);
  });
}
