// 공유 문장이 올라온 지 얼마나 됐는지(5차 339). 홈과 둘러보기가 같이 쓴다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/time_ago_label.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';
import 'package:parrokit/core/shared/utils/sentence_age_label.dart';

void main() {
  final now = DateTime(2026, 11, 16, 12);

  test('방금·분·시간·일', () {
    expect(
        sentenceAgeLabel(now.subtract(const Duration(seconds: 20)), now), justNowLabel);
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
    expect(sentenceAgeLabel(null, now), justNowLabel);
  });


  test('문장 카드와 커뮤니티가 같은 말을 쓴다(5차 443)', () {
    // 전에는 같은 계산이 두 벌이었고, 막 올라온 것을 한쪽은 '방금',
    // 다른 쪽은 '방금 전'이라고 불렀다.
    final now = DateTime(2026, 11, 17, 12);
    for (final ago in [
      const Duration(seconds: 20),
      const Duration(minutes: 5),
      const Duration(hours: 3),
      const Duration(days: 2),
      const Duration(days: 30),
    ]) {
      final at = now.subtract(ago);
      expect(sentenceAgeLabel(at, now), formatCommunityTimeAgo(at, now: now),
          reason: '$ago');
    }
  });
}
