// 공유 문장이 올라온 지 얼마나 됐는지(5차 339). 홈과 둘러보기가 같이 쓴다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/sentence_age_label.dart';

void main() {
  final now = DateTime(2026, 11, 16, 12);

  test('방금·분·시간·일', () {
    expect(
        sentenceAgeLabel(now.subtract(const Duration(seconds: 20)), now), '방금');
    expect(sentenceAgeLabel(now.subtract(const Duration(minutes: 5)), now),
        '5분 전');
    expect(
        sentenceAgeLabel(now.subtract(const Duration(hours: 3)), now), '3시간 전');
    expect(
        sentenceAgeLabel(now.subtract(const Duration(days: 2)), now), '2일 전');
  });

  test('일주일이 넘으면 날짜로, 해가 다르면 연도까지', () {
    expect(sentenceAgeLabel(DateTime(2026, 10, 2), now), '10월 2일');
    expect(sentenceAgeLabel(DateTime(2025, 10, 2), now), contains('2025'));
  });

  test('시각을 모르면 방금으로 둔다', () {
    expect(sentenceAgeLabel(null, now), '방금');
  });
}
