// 백업에 문장·단어를 담고 되돌린다(5차 345, 사용자 요청).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/study_data_transfer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MySentenceStore.cloud = null;
    MyWordStore.cloud = null;
  });

  test('담았다가 그대로 되돌린다', () async {
    await MySentenceStore.add('me',
        language: '영어', text: 'Nice to meet you.', translation: '만나서 반가워요.');
    await MyWordStore.add('me',
        language: '영어',
        word: 'huge',
        meaning: '엄청 큰',
        synonyms: ['big'],
        examples: [const WordExample(text: 'It is huge.', translation: '커요.')]);

    final json = await exportStudyData('me');

    // 다른 기기(빈 저장소)에서 되돌린다.
    SharedPreferences.setMockInitialValues({});
    final count = await importStudyData('me', json);
    expect(count.sentences, 1);
    expect(count.words, 1);

    final sentence = (await MySentenceStore.loadFor('me', '영어')).single;
    expect(sentence.text, 'Nice to meet you.');
    expect(sentence.translation, '만나서 반가워요.');
    final word = (await MyWordStore.loadFor('me', '영어')).single;
    expect(word.word, 'huge');
    expect(word.meaning, '엄청 큰');
    expect(word.synonyms, ['big']);
    expect(word.examples.single.text, 'It is huge.');
  });

  test('이미 있는 것은 건너뛴다', () async {
    await MySentenceStore.add('me', language: '영어', text: 'Hello there!');
    final json = await exportStudyData('me');
    final count = await importStudyData('me', json);
    expect(count.sentences, 0, reason: '같은 문장은 또 넣지 않는다');
    expect((await MySentenceStore.loadFor('me', '영어')).length, 1);
  });

  test('고른 것만 담고, 고른 것만 되돌린다', () async {
    await MySentenceStore.add('me', language: '영어', text: 'Hello there!');
    await MyWordStore.add('me', language: '영어', word: 'huge');

    final onlyWords = await exportStudyData('me', sentences: false);
    expect((jsonDecode(onlyWords) as Map)['sentences'], isEmpty);

    final all = await exportStudyData('me');
    SharedPreferences.setMockInitialValues({});
    final count = await importStudyData('me', all, words: false);
    expect(count.sentences, 1);
    expect(count.words, 0);
    expect(await MyWordStore.loadFor('me', '영어'), isEmpty);
  });

  test('깨진 글이나 모르는 형식은 아무것도 넣지 않는다', () async {
    expect(await importStudyData('me', '{'), (sentences: 0, words: 0));
    expect(
        await importStudyData(
            'me', jsonEncode({'version': 99, 'sentences': []})),
        (sentences: 0, words: 0));
    expect(await MySentenceStore.load('me'), isEmpty);
  });

  group('백업에 담은 것 목록', () {
    test('예전 백업(목록 없음)은 클립만 담긴 것으로 읽는다', () {
      final parts = BackupParts.fromManifest(null);
      expect(parts.clips, isTrue);
      expect(parts.sentences, isFalse);
      expect(parts.words, isFalse);
    });

    test('적힌 것만 담긴 것으로 읽는다', () {
      final parts = BackupParts.fromManifest(['sentences', 'words']);
      expect(parts.clips, isFalse);
      expect(parts.sentences, isTrue);
      expect(parts.names, ['sentences', 'words']);
    });

    test('고른 것과 들어 있는 것 둘 다인 것만 되돌린다', () {
      const picked = BackupParts.all();
      final inFile = BackupParts.fromManifest(['clips']);
      expect(picked.intersect(inFile),
          const BackupParts(clips: true, sentences: false, words: false));
    });
  });

  test('되돌린 결과를 사람 말로 적는다', () {
    expect(studyRestoreSummary((sentences: 12, words: 3)),
        '문장 12개 · 단어 3개를 불러왔어요.');
    expect(
        studyRestoreSummary((sentences: 0, words: 0)), '새로 들어온 문장과 단어는 없어요.');
  });
}
