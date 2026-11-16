// 로그인한 사람의 '내 문장'을 서버에 두는 곳(5차 359).
//
// 내 문장과 공개 문장은 같은 문서이고 visibility로만 갈린다. 그 규칙이 조용히
// 어긋나면 남의 문장이 보이거나 공개가 풀릴 수 있어 테스트로 묶어 둔다.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_cloud_store.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late SentenceCloudStore store;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    store = SentenceCloudStore(firestore: firestore);
  });

  Future<Map<String, dynamic>> docOf(String id) async =>
      (await firestore.collection('sentences').doc(id).get()).data()!;

  Future<String> firstId(String ownerId) async =>
      (await store.load(ownerId)).first.id;

  test('추가한 문장은 내 것이고 비공개로 시작한다', () async {
    expect(
        await store.add('me',
            language: '영어', text: 'Hello there!', translation: '안녕하세요!'),
        isTrue);

    final saved = (await store.load('me')).single;
    expect(saved.text, 'Hello there!');
    expect(saved.id.startsWith('my-'), isTrue, reason: '앱이 내 문장인지 id로 안다');

    final raw = await docOf(saved.id);
    expect(raw['visibility'], SentenceCloudStore.private);
    expect(raw['ownerId'], 'me');
    expect(raw['authorId'], 'me', reason: '내가 만든 문장은 원작자도 나다');
  });

  test('같은 언어에 같은 문장은 또 넣지 않는다. 다른 언어면 넣는다', () async {
    await store.add('me', language: '영어', text: 'Hello there!');

    expect(await store.add('me', language: '영어', text: '  Hello there!  '),
        isFalse);
    expect(
        await store.add('me', language: '일본어', text: 'Hello there!'), isTrue);
    expect((await store.load('me')).length, 2);
  });

  test('빈 문장은 넣지 않는다', () async {
    expect(await store.add('me', language: '영어', text: '   '), isFalse);
    expect(await store.load('me'), isEmpty);
  });

  test('남의 문장을 저장한 사본은 원작자를 지킨다', () async {
    await store.add('me',
        language: '영어',
        text: 'Where were we?',
        author: '봄배',
        authorId: 'mina',
        sourceSharedId: 'shared-1');

    final raw = await docOf(await firstId('me'));
    expect(raw['ownerId'], 'me');
    expect(raw['authorId'], 'mina');
    expect(raw['authorName'], '봄배');
    expect(raw['sourceSharedId'], 'shared-1');
  });

  test('다른 사람 문장은 내 목록에 오지 않는다', () async {
    await store.add('me', language: '영어', text: '내 것');
    await store.add('other', language: '영어', text: '남의 것');

    expect((await store.load('me')).map((s) => s.text), ['내 것']);
  });

  test('고치면 글만 바뀌고 공개 여부·좋아요는 그대로다', () async {
    await store.add('me', language: '영어', text: 'Helo', translation: '안녕');
    final id = await firstId('me');
    await firestore.collection('sentences').doc(id).update({
      'visibility': SentenceCloudStore.public,
      'likeCount': 7,
    });

    await store.update(id,
        text: 'Hello', pronunciation: '헬로', translation: '안녕하세요');

    final raw = await docOf(id);
    expect(raw['text'], 'Hello');
    expect(raw['pronunciation'], '헬로');
    expect(raw['translation'], '안녕하세요');
    expect(raw['visibility'], SentenceCloudStore.public, reason: '공개는 그대로');
    expect(raw['likeCount'], 7);
  });

  test('공개 중인 내 문장 id만 돌려준다', () async {
    await store.add('me', language: '영어', text: '공개할 것');
    await store.add('me', language: '영어', text: '비공개');
    await store.add('other', language: '영어', text: '남의 공개 문장');

    final mine = await store.load('me');
    final openId = mine.firstWhere((s) => s.text == '공개할 것').id;
    await firestore
        .collection('sentences')
        .doc(openId)
        .update({'visibility': SentenceCloudStore.public});
    final othersId = (await store.load('other')).single.id;
    await firestore
        .collection('sentences')
        .doc(othersId)
        .update({'visibility': SentenceCloudStore.public});

    expect(await store.publishedIds('me'), {openId});
  });

  test('지우면 목록에서 사라진다', () async {
    await store.add('me', language: '영어', text: 'Bye');
    await store.remove(await firstId('me'));
    expect(await store.load('me'), isEmpty);
  });
}
