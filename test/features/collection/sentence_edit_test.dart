// 저장한 문장을 고칠 수 있다(5차, 사용자 요청).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

DefaultConversationSentence _sentence(String text) =>
    DefaultConversationSentence(
      id: 'my-영어-1',
      language: '영어',
      text: text,
      translation: '뜻',
      pronunciation: '발음',
      topic: '내 문장',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('고친 내용이 저장되고 id는 그대로다', () async {
    await MySentenceStore.add('guest',
        language: '영어', text: 'Helo there', translation: '안녕');
    final before = (await MySentenceStore.load('guest')).single;

    final ok = await MySentenceStore.update('guest', before.id,
        text: 'Hello there', pronunciation: '헬로 데어', translation: '안녕하세요');
    expect(ok, isTrue);

    final after = (await MySentenceStore.load('guest')).single;
    expect(after.id, before.id, reason: '연습 기록이 id로 묶여 있다');
    expect(after.text, 'Hello there');
    expect(after.pronunciation, '헬로 데어');
    expect(after.translation, '안녕하세요');
    expect(after.topic, before.topic);
  });

  test('같은 언어에 같은 문장이 있으면 고치지 않는다', () async {
    await MySentenceStore.add('guest', language: '영어', text: 'One');
    await MySentenceStore.add('guest', language: '영어', text: 'Two');
    final two = (await MySentenceStore.load('guest'))
        .firstWhere((s) => s.text == 'Two');

    expect(await MySentenceStore.update('guest', two.id, text: 'One'), isFalse);
    expect((await MySentenceStore.load('guest')).map((s) => s.text),
        containsAll(['One', 'Two']));
  });

  test('없는 문장이나 빈 글은 고치지 않는다', () async {
    expect(await MySentenceStore.update('guest', 'no-such', text: 'A'), isFalse);
    await MySentenceStore.add('guest', language: '영어', text: 'One');
    final one = (await MySentenceStore.load('guest')).single;
    expect(await MySentenceStore.update('guest', one.id, text: '   '), isFalse);
  });

  test('못 고치는 까닭을 말해 준다', () {
    final before = _sentence('Hello');
    expect(sentenceEditBlockedReason(text: '  ', before: before),
        '문장을 적어 주세요.');
    expect(
        sentenceEditBlockedReason(
            text: 'Hello', before: before, pronunciation: '발음', translation: '뜻'),
        '바뀐 것이 없어요.');
    expect(
        sentenceEditBlockedReason(
            text: 'Hello!', before: before, pronunciation: '발음', translation: '뜻'),
        isNull);
  });
  test('공유 중인 문장 id를 읽는다(기기 저장 계정은 없음)', () async {
    // 공개는 로그인해야 하므로 게스트는 늘 비어 있다.
    expect(await MySentenceStore.publishedIds('guest'), isEmpty);
  });
}
