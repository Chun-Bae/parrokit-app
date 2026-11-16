// 공개 문장과 내 문장을 같은 것으로 보는 규칙(5차 364).
//
// 보관함 둘러보기와 홈 '요즘 뜨는 문장'이 이 규칙을 각자 적어 둬서, 한쪽만
// 고치면 같은 문장이 한 화면에서만 '저장됨'으로 보일 수 있었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/shared_sentence_match.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';

DefaultConversationSentence _mine({
  String id = 'my-1',
  String language = '영어',
  String text = 'Hello',
  String sourceSharedId = '',
}) =>
    DefaultConversationSentence(
      id: id,
      language: language,
      text: text,
      translation: '안녕',
      pronunciation: '헬로',
      topic: '내 문장',
      sourceSharedId: sourceSharedId,
    );

SharedSentence _shared({
  String id = 'shared-1',
  String language = '영어',
  String text = 'Hello',
}) =>
    SharedSentence(
      id: id,
      language: language,
      text: text,
      translation: '안녕',
      pronunciation: '헬로',
      topic: '공유 문장',
      authorId: 'someone',
      authorName: 'Mina',
      likeCount: 0,
      createdAt: DateTime(2026, 11, 17),
    );

void main() {
  test('문서가 같으면(내가 올린 문장) 저장한 것으로 본다', () {
    final mine = [_mine(id: 'shared-1')];
    expect(savedCopyOfShared(mine, _shared())?.id, 'shared-1');
  });

  test('저장한 사본은 sourceSharedId로 찾는다', () {
    final mine = [_mine(text: '다른 글', sourceSharedId: 'shared-1')];
    expect(savedCopyOfShared(mine, _shared()), isNotNull);
  });

  test('같은 언어에 같은 글이면 앞뒤 공백은 보지 않는다', () {
    final mine = [_mine(text: '  Hello  ')];
    expect(savedCopyOfShared(mine, _shared()), isNotNull);
  });

  test('언어가 다르면 같은 글이어도 아니다', () {
    final mine = [_mine(language: '일본어')];
    expect(savedCopyOfShared(mine, _shared()), isNull);
  });

  test('없으면 null', () {
    expect(savedCopyOfShared(const [], _shared()), isNull);
  });

  test('두 화면이 같은 함수를 쓴다', () {
    for (final path in [
      'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart',
      'lib/features/home/dashboard/presentation/widgets/trending_sentences_preview.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('savedCopyOfShared'));
    }
  });

  test('안내 말투는 ~해 주세요로 띄어 쓴다', () {
    final bad = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        if (!line.contains('해주세요')) continue;
        if (!line.contains("'") && !line.contains('"')) continue;
        bad.add('${file.path}: $trimmed');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
