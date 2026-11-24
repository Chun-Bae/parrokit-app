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
    // 일주일이 넘으면 날짜, 해가 다르면 연도까지.
    expect(relativeDayLabel(now, DateTime(2026, 10, 1)), '10월 1일');
    expect(relativeDayLabel(now, DateTime(2025, 12, 30)), '2025년 12월 30일');
  });

  test('친밀도는 청취 1점, 따라 말하기 2점으로 단계가 오른다', () {
    expect(affinityOf(const SentenceActivity()).level, 1);
    expect(affinityOf(const SentenceActivity(listenCount: 3)).level, 2);
    expect(affinityOf(const SentenceActivity(practiceCount: 5)).level, 3);
    final mid = affinityOf(const SentenceActivity(listenCount: 6));
    expect(mid.level, 2);
    expect(mid.progress, closeTo(3 / 7, 1e-9));
    // 예전 기록은 횟수당 2점으로 읽으므로 25번 = 50점 = Lv.5다. 위에
    // 두 단계를 얹었으니(5차 566) 최고 단계는 아니다.
    final grown = affinityOf(const SentenceActivity(practiceCount: 25));
    expect(grown.level, 5);
    expect(grown.isMax, isFalse);
    final max = affinityOf(const SentenceActivity(practiceCount: 75));
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

  test('숙련도 이름이 친밀도 단계 이름과 엇갈리지 않는다', () {
    // 홈 범례는 숙련도로, 문장 목록은 친밀도로 같은 문장을 부른다. 마지막
    // 숙련도를 '익숙함'이라 적던 때는 'Lv.2 익숙한' 문장이 홈에서 '익히는
    // 중'이고 범례는 '익숙함 0'이었다(5차).
    // 마지막 숙련도가 시작되는 점수에서 친밀도도 같은 이름으로 올라선다.
    expect(masteryOf(const SentenceActivity(listenCount: 10)),
        SentenceMastery.familiar);
    expect(affinityOf(const SentenceActivity(listenCount: 10)).name, '편안한');
    expect(SentenceMastery.familiar.label, '편안함');

    // 그 아래 단계의 친밀도 이름을 윗 묶음에 가져다 쓰지 않는다. '익숙한'은
    // 3점부터(Lv.2)인데 숙련도는 10점부터를 '익숙함'이라 불렀다.
    final below = <String>{
      for (var points = 0; points < 10; points++)
        affinityOf(SentenceActivity(listenCount: points)).name,
    };
    for (final mastery in SentenceMastery.values) {
      final stem = mastery.label.replaceAll('함', '한');
      expect(below.contains(stem), isFalse, reason: mastery.label);
    }
  });

  test('마지막 단계 뒤로는 진행률이 1이고 다음 목표가 없다', () {
    final max = affinityOf(const SentenceActivity(listenCount: 500));
    expect(max.isMax, isTrue);
    expect(max.next, isNull);
    expect(max.progress, 1);
  });
}
