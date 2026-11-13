import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';

void main() {
  test('청취와 따라 말하기 횟수로 숙련도를 나눈다', () {
    expect(masteryOf(const SentenceActivity()), SentenceMastery.fresh);
    expect(masteryOf(const SentenceActivity(listenCount: 1)),
        SentenceMastery.learning);
    expect(masteryOf(const SentenceActivity(listenCount: 9)),
        SentenceMastery.learning);
    expect(masteryOf(const SentenceActivity(listenCount: 10)),
        SentenceMastery.familiar);
    // 따라 말하기는 두 배로 센다.
    expect(masteryOf(const SentenceActivity(practiceCount: 5)),
        SentenceMastery.familiar);
  });

  test('날짜 차이를 오늘, 어제, N일 전으로 표시한다', () {
    final now = DateTime(2026, 10, 28, 1);
    expect(relativeDayLabel(now, DateTime(2026, 10, 28, 23)), '오늘');
    expect(relativeDayLabel(now, DateTime(2026, 10, 27, 23)), '어제');
    expect(relativeDayLabel(now, DateTime(2026, 10, 25)), '3일 전');
  });

  test('친밀도는 청취 1점, 따라 말하기 2점으로 단계가 오른다', () {
    expect(affinityOf(const SentenceActivity()).level, 1);
    expect(affinityOf(const SentenceActivity(listenCount: 3)).level, 2);
    expect(affinityOf(const SentenceActivity(practiceCount: 5)).level, 3);
    final mid = affinityOf(const SentenceActivity(listenCount: 6));
    expect(mid.level, 2);
    expect(mid.progress, closeTo(3 / 7, 1e-9));
    final max = affinityOf(const SentenceActivity(practiceCount: 25));
    expect(max.level, SentenceAffinity.maxLevel);
    expect(max.isMax, isTrue);
    expect(max.progress, 1);
  });

  test('친밀도 단계는 경계 점수에서 바로 오르고 바로 아래에서는 오르지 않는다', () {
    int level(int listen, [int practice = 0]) => affinityOf(
            SentenceActivity(listenCount: listen, practiceCount: practice))
        .level;
    for (final (below, at, lv) in [
      (2, 3, 2),
      (9, 10, 3),
      (24, 25, 4),
      (49, 50, 5)
    ]) {
      expect(level(below), lv - 1, reason: '$below점');
      expect(level(at), lv, reason: '$at점');
    }
    // 따라 말하기는 2점이라 1.5회 같은 반올림 없이 정확히 센다.
    expect(level(1, 1), 2); // 1 + 2 = 3점
    expect(level(0, 12), 3); // 24점은 아직 4단계(25점) 아래
  });

  test('마지막 단계 뒤로는 진행률이 1이고 다음 목표가 없다', () {
    final max = affinityOf(const SentenceActivity(listenCount: 500));
    expect(max.isMax, isTrue);
    expect(max.next, isNull);
    expect(max.progress, 1);
  });
}
