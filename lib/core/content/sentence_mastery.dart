import 'sentence_activity_store.dart';

/// 문장별 숙련도 단계. 청취와 따라 말하기 횟수로 계산하며 따로 저장하지 않는다.
enum SentenceMastery {
  fresh('새 문장'),
  learning('익히는 중'),
  familiar('익숙함');

  const SentenceMastery(this.label);
  final String label;
}

/// 따라 말하기는 직접 소리 내는 연습이라 청취보다 두 배로 센다.
const _familiarScore = 10;

SentenceMastery masteryOf(SentenceActivity activity) {
  final score = activity.listenCount + activity.practiceCount * 2;
  if (score <= 0) return SentenceMastery.fresh;
  if (score < _familiarScore) return SentenceMastery.learning;
  return SentenceMastery.familiar;
}

/// "오늘", "어제", "N일 전" 형태로 날짜 차이를 표현한다.
String relativeDayLabel(DateTime now, DateTime then) {
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(then.year, then.month, then.day))
      .inDays;
  if (days <= 0) return '오늘';
  if (days == 1) return '어제';
  return '$days일 전';
}
