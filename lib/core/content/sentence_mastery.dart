import 'package:parrokit/core/shared/utils/calendar_date_label.dart';
import 'sentence_activity_store.dart';

/// 문장별 숙련도 단계. 청취와 따라 말하기 횟수로 계산하며 따로 저장하지 않는다.
enum SentenceMastery {
  fresh('새 문장'),
  learning('익히는 중'),
  familiar('익숙함');

  const SentenceMastery(this.label);
  final String label;
}

/// 따라 말하기는 직접 소리 내는 연습이라 청취보다 많이 센다. 얼마나 비슷하게
/// 말했는지에 따라 한 번에 0~2점이다(5차).
const _familiarScore = 10;

SentenceMastery masteryOf(SentenceActivity activity) {
  final score = activity.listenScore + activity.practiceScore;
  if (score <= 0) return SentenceMastery.fresh;
  if (score < _familiarScore) return SentenceMastery.learning;
  return SentenceMastery.familiar;
}

/// 문장별 친밀도. 숙련도와 같은 점수(청취 1점, 따라 말하기는 점수에 따라 0~2점)로
/// 계산하고 따로 저장하지 않는다.
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

  /// 단계가 시작되는 점수와 이름.
  ///
  /// 앞의 다섯은 한 글자도 바꾸지 않는다 - 바꾸면 이미 올려 둔 사람의
  /// 단계가 달라진다. 위로 둘만 얹는다(5차 566). 50점은 하루 상한
  /// 6점으로 최소 9일, 90점은 거기서 7일, 150점은 다시 10일이 걸린다.
  /// 최고 단계 뒤가 비어 있어 '하루 만에 끝'이던 것을 늘린 것이다.
  static const _steps = [
    (0, '낯선'),
    (3, '익숙한'),
    (10, '편안한'),
    (25, '자연스러운'),
    (50, '능숙한'),
    (90, '몸에 붙은'),
    (150, '내 말 같은'),
  ];

  static const maxLevel = 7;

  /// 뱃지 그림은 아직 다섯 개뿐이다(assets/badges/affinity_1~5).
  int get badgeLevel => level > 5 ? 5 : level;
}

/// 이 단계부터 문장 카드에 금빛을 깐다.
const int goldenAffinityLevel = 5;

/// 단계가 오를 때 캐릭터가 받는 XP(5차 566).
///
/// XP는 **한 번만 생기는 일**에만 붙는다. 같은 문장을 500번 반복해도
/// 받는 XP는 그 문장이 오른 단계 수만큼이다. 반복은 크래커가 맡는다.
const List<int> affinityLevelXp = [0, 0, 2, 4, 8, 14, 20, 30];

/// [from]단계에서 [to]단계로 올랐을 때 주는 XP.
int affinityXpBetween(int from, int to) {
  var sum = 0;
  for (var level = from + 1; level <= to; level++) {
    if (level < affinityLevelXp.length) sum += affinityLevelXp[level];
  }
  return sum;
}

/// 단계별 복습 주기(일). 낯선 단계는 아직 주기가 없다.
///
/// 단어 쪽 WordReviewStore.intervals(1·3·7·14·30)와 같은 결로 맞춘다.
/// 점수를 깎는 대신 '다시 볼 때'만 알린다 - 쌓은 것을 빼앗지 않는다.
const List<int?> affinityReviewDays = [null, null, 3, 7, 14, 30, 60, 90];

/// 이 문장을 다시 볼 때가 됐는지. 한 번도 연습하지 않았으면 아니다.
bool needsReview(SentenceActivity activity, {DateTime? now}) {
  final last = activity.lastPracticedAt;
  if (last == null) return false;
  final level = affinityOf(activity).level;
  final days = level < affinityReviewDays.length
      ? affinityReviewDays[level]
      : affinityReviewDays.last;
  if (days == null) return false;
  return (now ?? DateTime.now()).difference(last).inDays >= days;
}

SentenceAffinity affinityOf(SentenceActivity activity) {
  final points = activity.listenScore + activity.practiceScore;
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
  return calendarDateLabel(then, now);
}
