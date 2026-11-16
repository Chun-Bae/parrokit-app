// 단어 복습 일정(5차 358). 간격·쉬움 계수는 눈으로 보기 어려운 규칙이라
// 여기에 묶어 둔다. 전에는 다른 테스트들이 일부만 스쳐 지나갔다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/word_review_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('다음 간격', () {
    test("'다시'는 오늘 다시 본다", () {
      expect(
          WordReviewStore.nextInterval(
              interval: 30, step: 4, ease: 2.5, rating: ReviewRating.again),
          0);
    });

    test('처음 두 번은 1일, 3일', () {
      expect(
          WordReviewStore.nextInterval(
              interval: 0, step: 0, ease: 2.5, rating: ReviewRating.known),
          WordReviewStore.firstInterval);
      expect(
          WordReviewStore.nextInterval(
              interval: 1, step: 1, ease: 2.5, rating: ReviewRating.known),
          WordReviewStore.secondInterval);
    });

    test('그 뒤로는 간격에 쉬움 계수를 곱한다', () {
      expect(
          WordReviewStore.nextInterval(
              interval: 10, step: 2, ease: 2.5, rating: ReviewRating.known),
          25);
    });

    test("'쉬움'은 처음엔 4일, 그다음부터는 1.3배를 더 민다", () {
      expect(
          WordReviewStore.nextInterval(
              interval: 0, step: 0, ease: 2.65, rating: ReviewRating.easy),
          WordReviewStore.easyFirstInterval);
      expect(
        WordReviewStore.nextInterval(
            interval: 10, step: 2, ease: 2.0, rating: ReviewRating.easy),
        26, // (10 * 2.0) * 1.3
      );
    });

    test('아무리 밀어도 1년을 넘기지 않는다', () {
      expect(
          WordReviewStore.nextInterval(
              interval: 400, step: 9, ease: 3.5, rating: ReviewRating.easy),
          WordReviewStore.maxInterval);
    });
  });

  group('쉬움 계수', () {
    test("'다시'면 내려가고 '쉬움'이면 올라간다", () {
      expect(WordReviewStore.nextEase(2.5, ReviewRating.again),
          closeTo(2.3, 0.0001));
      expect(WordReviewStore.nextEase(2.5, ReviewRating.known), 2.5);
      expect(WordReviewStore.nextEase(2.5, ReviewRating.easy),
          closeTo(2.65, 0.0001));
    });

    test('너무 낮거나 높아지지 않는다', () {
      expect(WordReviewStore.nextEase(1.3, ReviewRating.again),
          WordReviewStore.minEase);
      expect(WordReviewStore.nextEase(3.5, ReviewRating.easy), 3.5);
    });
  });

  group('기록하기', () {
    test("'알아요'면 단계가 오르고 기한이 미뤄진다", () async {
      final at = DateTime(2026, 11, 17, 9);

      final first = await WordReviewStore.record('me', 'w1',
          rating: ReviewRating.known, now: at);
      expect(first.step, 1);
      expect(first.intervalDays, 1);
      expect(WordReviewStore.dueLabel(first.dueAt, at), '내일');

      final second = await WordReviewStore.record('me', 'w1',
          rating: ReviewRating.known, now: at);
      expect(second.step, 2);
      expect(second.intervalDays, 3);
    });

    test("'다시'면 단계가 처음으로 돌아가고 오늘 다시 본다", () async {
      final at = DateTime(2026, 11, 17, 9);
      await WordReviewStore.record('me', 'w1',
          rating: ReviewRating.known, now: at);
      await WordReviewStore.record('me', 'w1',
          rating: ReviewRating.known, now: at);

      final again = await WordReviewStore.record('me', 'w1',
          rating: ReviewRating.again, now: at);

      expect(again.step, 0);
      expect(again.intervalDays, 0);
      expect(WordReviewStore.dueLabel(again.dueAt, at), '오늘');
    });

    test('기록은 저장되고 다시 읽힌다. 계정마다 따로다', () async {
      final at = DateTime(2026, 11, 17, 9);
      await WordReviewStore.record('me', 'w1',
          rating: ReviewRating.known, now: at);

      final mine = await WordReviewStore.loadAll('me');
      expect(mine['w1']?.step, 1);
      expect(await WordReviewStore.loadAll('other'), isEmpty);
    });
  });

  group('적는 말', () {
    final now = DateTime(2026, 11, 17, 9);

    test('오늘·내일·n일 뒤', () {
      expect(WordReviewStore.intervalLabel(0), '오늘');
      expect(WordReviewStore.intervalLabel(1), '내일');
      expect(WordReviewStore.intervalLabel(8), '8일 뒤');
    });

    test('기한이 지났으면 오늘로 본다', () {
      expect(WordReviewStore.dueLabel(DateTime(2026, 11, 10), now), '오늘');
      expect(WordReviewStore.nextSeenLabel(DateTime(2026, 11, 25), now),
          '8일 뒤 다시');
    });
  });
}
