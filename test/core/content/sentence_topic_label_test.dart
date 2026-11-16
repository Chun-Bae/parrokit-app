// 공유 문장 주제 이름(5차 337, 사용자 신고: 남이 올린 문장이 '내 문장'으로 보인다).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_topic_label.dart';

void main() {
  test('남이 직접 적어 올린 문장은 내 문장이라 하지 않는다', () {
    expect(sentenceTopicLabel('내 문장', mine: false), '직접 쓴 문장');
    expect(sentenceTopicLabel('', mine: false), '직접 쓴 문장');
  });

  test('내가 올린 문장은 그대로 내 문장', () {
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
