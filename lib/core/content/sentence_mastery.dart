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

/// 문장별 친밀도. 숙련도와 같은 점수(청취 1점, 따라 말하기 2점)로 계산하고 따로 저장하지 않는다.
/// 한 번 오른 단계는 내려가지 않는다.
class SentenceAffinity {
  const SentenceAffinity._(
      this.level, this.name, this.points, this.floor, this.next);

  /// 1부터 시작하는 단계.
  final int level;
  final String name;
  final int points;

  /// 이 단계가 시작되는 점수와 다음 단계가 시작되는 점수. 마지막 단계면 [next]는 null.
  final int floor;
  final int? next;

  bool get isMax => next == null;

  /// 다음 단계까지 진행률(0~1). 마지막 단계는 1.
  double get progress =>
      next == null ? 1 : ((points - floor) / (next! - floor)).clamp(0.0, 1.0);

  static const _steps = [
    (0, '낯선'),
    (3, '익숙한'),
    (10, '편안한'),
    (25, '자연스러운'),
    (50, '능숙한'),
  ];

  static const maxLevel = 5;
}

SentenceAffinity affinityOf(SentenceActivity activity) {
  final points = activity.listenCount + activity.practiceCount * 2;
  var index = 0;
  for (var i = 0; i < SentenceAffinity._steps.length; i++) {
    if (points >= SentenceAffinity._steps[i].$1) index = i;
  }
  final step = SentenceAffinity._steps[index];
  final next = index + 1 < SentenceAffinity._steps.length
      ? SentenceAffinity._steps[index + 1].$1
      : null;
  return SentenceAffinity._(index + 1, step.$2, points, step.$1, next);
}

/// "오늘", "어제", "N일 전" 형태로 날짜 차이를 표현한다. 일주일이 넘으면 커뮤니티와
/// 같이 '11월 7일'(올해가 아니면 연도까지)로 보인다(5차, 예전엔 '120일 전').
String relativeDayLabel(DateTime now, DateTime then) {
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(then.year, then.month, then.day))
      .inDays;
  if (days <= 0) return '오늘';
  if (days == 1) return '어제';
  if (days < 7) return '$days일 전';
  return then.year == now.year
      ? '${then.month}월 ${then.day}일'
      : '${then.year}년 ${then.month}월 ${then.day}일';
}
