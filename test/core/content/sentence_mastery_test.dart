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
}
