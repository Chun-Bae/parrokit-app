// 공유 문장이 안 보일 때 할 말(5차 500).
//
// 보관함 문장 탭의 주제 칩은 '공유 문장 둘러보기'만 거른다. '일상'을 고르면
// 둘러보기가 비는데, 그때도 '아직 공유된 문장이 없어요. 내 문장을 공유해
// 보세요.'라고 해서 다른 주제에 문장이 있는데도 아무도 공유하지 않은 것처럼
// 읽혔다. 갈 길도 직접 공유하라는 것 하나뿐이었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_topic_label.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_filter_row.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('하나도 공유되지 않았으면 그대로 공유하라고 한다', () {
    expect(
        sharedSentencesEmptyMessage(
            category: allSentenceTopics, anyShared: false),
        noSharedSentenceMessage);
    // 주제를 골랐어도 공유된 게 정말 하나도 없으면 주제 탓이 아니다.
    expect(sharedSentencesEmptyMessage(category: '일상', anyShared: false),
        noSharedSentenceMessage);
  });

  test('주제로 걸러 비었으면 그 주제를 짚는다', () {
    final message =
        sharedSentencesEmptyMessage(category: '일상', anyShared: true);
    expect(message, contains('일상'));
    expect(message, isNot(noSharedSentenceMessage));
    // 아무도 공유하지 않았다고 말하지 않는다.
    expect(message.contains('아직 공유된 문장이 없어요'), isFalse);
  });

  test('주제를 안 골랐는데 비면 거른 탓으로 돌리지 않는다', () {
    expect(
        sharedSentencesEmptyMessage(
            category: allSentenceTopics, anyShared: true),
        noSharedSentenceMessage);
    expect(sharedSentencesEmptyMessage(category: '  ', anyShared: true),
        noSharedSentenceMessage);
  });

  test("칩 목록 첫 칸과 거르지 않는 값이 같은 '전체'를 쓴다", () {
    expect(sentenceCategories.first, allSentenceTopics);
  });

  test('두 자리가 같은 글귀 함수를 쓴다', () {
    // 둘러보기 띠(보관함)와 둘러보기 화면 목록이 따로 적어 갈라졌었다.
    final screen = _code('lib/features/collection/shell/presentation/'
        'widgets/sentence_collection_preview.dart');
    expect('sharedSentencesEmptyMessage('.allMatches(screen).length, 2);
    // 손으로 적은 글귀가 남아 있지 않다.
    expect(screen.contains("'아직 공유된 문장이 없어요"), isFalse);
    // 걸러 비었을 때는 주제를 되돌리는 길을 준다.
    expect(screen, contains('showAllSentenceTopicsLabel'));
    expect(screen, contains('setState(() => category = allSentenceTopics)'));
  });
}
