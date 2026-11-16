// 공유 문장 주제 이름(5차 337·338, 사용자 신고).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_topic_label.dart';

void main() {
  test('남이 올린 문장은 공유 문장', () {
    // '내 문장'도 '직접 쓴 문장'도 보는 사람이 쓴 것처럼 읽혔다. 칩을 빼 보니
    // 그 카드만 비어 어색했다(사용자). '내 문장'과 짝이 되는 말로 적는다.
    expect(sentenceTopicLabel('내 문장', mine: false), '공유 문장');
    expect(sentenceTopicLabel('', mine: false), '공유 문장');
  });

  test('내가 올린 문장은 내 문장', () {
    expect(sentenceTopicLabel('내 문장', mine: true), '내 문장');
    expect(sentenceTopicLabel('  ', mine: true), '내 문장');
  });

  test('고른 주제는 누가 보든 그대로', () {
    for (final mine in [true, false]) {
      expect(sentenceTopicLabel('카페', mine: mine), '카페');
      expect(sentenceTopicLabel('여행', mine: mine), '여행');
    }
  });
}
