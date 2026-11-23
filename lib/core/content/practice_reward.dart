import 'dart:math';

/// 연습하면 크래커를 주는 규칙(5차 505, 사용자와 정함).
///
/// 따라 말하기 한 번, 단어 복습 한 번마다 크래커를 뽑아 준다. 액수는 고정이
/// 아니라 아래 표에서 뽑는다. 액수가 클수록 확률이 낮다. 고정 액수는 며칠이면
/// 시들해지는데, 뽑기는 같은 평균으로도 계속 궁금하게 만든다(변동 비율).
///
/// 대신 하루·한 주·한 달 상한을 둔다. 상한이 없으면 따라 말하기를 50번 눌러
/// 긁을 수 있고, 패롯 1 = 크래커 1,000이라 그대로 돈이 된다.
///
/// 상한에 걸리면 뽑은 액수를 남은 만큼으로 깎아 준다(0이 될 수도 있다).
/// 그래서 상한은 정확히 지켜진다.
///
/// ## 아직 서버가 아니다
///
/// 지금 크래커 잔액은 앱이 자기 문서에 쓸 수 있다(firestore.rules에도 그렇게
/// 적혀 있다). 그래서 이 지급도 앱에서 한다. 마음먹으면 고쳐 쓸 수 있다는
/// 뜻이고, 제대로 막으려면 지급을 서버 함수로 옮겨야 한다.

/// 모든 액수와 상한은 이 값의 배수다. 기댓값 계산이 이 단위로 돈다.
const int rewardUnit = 10;

/// 한 번 뽑을 때 나올 수 있는 액수와 그 무게.
///
/// 무게의 합이 1,000이라 무게를 그대로 '1,000번에 몇 번'으로 읽으면 된다.
/// 10크래커가 600번, 1,000크래커가 2번이다.
const List<RewardTier> rewardTiers = [
  RewardTier(crackers: 10, weight: 600),
  RewardTier(crackers: 30, weight: 280),
  RewardTier(crackers: 100, weight: 100),
  RewardTier(crackers: 300, weight: 18),
  RewardTier(crackers: 1000, weight: 2),
];

/// 한 번에 받을 수 있는 가장 큰 액수. 화면 글귀가 이 값을 쓴다.
int get rewardMaxCrackers =>
    rewardTiers.map((t) => t.crackers).reduce((a, b) => a > b ? a : b);

/// 하루에 받을 수 있는 크래커.
///
/// 한 번 평균이 약 31.8이라 열 번쯤 연습하면 찬다. 하루에 그 이상 하는 날은
/// 상한에 걸리지만, 연습 자체를 막지는 않는다.
const int rewardDailyCap = 300;

/// 레벨이 오르면 하루 상한만 늘린다(5차 566).
///
/// 주·달 상한은 그대로 둔다. 한 달 총량(5,000 = 패롯 5개)이 한 치도
/// 움직이지 않으면서, 주말에만 공부하는 사람이 300에서 끊기지 않는다.
/// 레벨이 **매일** 쓸모를 갖게 되는 가장 싼 방법이다.
int rewardDailyCapFor(int level) =>
    (rewardDailyCap + 20 * (level - 1)).clamp(rewardDailyCap, 600);

/// 한 주(7일)에 받을 수 있는 크래커. 하루 상한을 닷새 채운 만큼이다.
const int rewardWeeklyCap = 1500;

/// 한 달(28일)에 받을 수 있는 크래커. 패롯 5개어치다.
const int rewardMonthlyCap = 5000;

class RewardTier {
  const RewardTier({required this.crackers, required this.weight});

  final int crackers;

  /// 뽑힐 무게. 클수록 자주 나온다.
  final int weight;
}

/// 무게의 합.
int get rewardTotalWeight =>
    rewardTiers.fold<int>(0, (sum, t) => sum + t.weight);

/// 한 번 뽑을 때의 기댓값(크래커). 상한을 보지 않은 값이다.
double get rewardRollExpected =>
    rewardTiers.fold<double>(0, (sum, t) => sum + t.crackers * t.weight) /
    rewardTotalWeight;

/// 한 번 뽑는다. 상한은 보지 않는다([PracticeRewardStore.grant]가 깎는다).
int rollRewardCrackers([Random? random]) {
  final r = (random ?? Random()).nextInt(rewardTotalWeight);
  var passed = 0;
  for (final tier in rewardTiers) {
    passed += tier.weight;
    if (r < passed) return tier.crackers;
  }
  return rewardTiers.last.crackers;
}

/// 지급 한 번의 결과.
class RewardGrant {
  const RewardGrant({
    required this.crackers,
    this.rolled = 0,
    this.cap,
  });

  /// 실제로 준 크래커. 상한에 걸리면 [rolled]보다 작다.
  final int crackers;

  /// 상한을 보지 않고 뽑은 액수.
  final int rolled;

  /// 깎은 상한. 깎지 않았으면 null.
  final RewardCap? cap;

  bool get isEmpty => crackers <= 0;

  /// 상한에 걸려 깎였는지(0이 된 것도 포함).
  bool get capped => cap != null;
}

enum RewardCap {
  day('오늘'),
  week('이번 주'),
  month('이번 달');

  const RewardCap(this.label);

  /// '오늘'처럼 글귀에 끼워 쓴다.
  final String label;

  int get limit => switch (this) {
        RewardCap.day => rewardDailyCap,
        RewardCap.week => rewardWeeklyCap,
        RewardCap.month => rewardMonthlyCap,
      };
}

/// 지금까지 받은 크래커를 기간별로 적어 둔 것.
class RewardLedger {
  const RewardLedger({
    this.day = 0,
    this.week = 0,
    this.month = 0,
    this.dayKey = '',
    this.weekKey = '',
    this.monthKey = '',
  });

  final int day;
  final int week;
  final int month;
  final String dayKey;
  final String weekKey;
  final String monthKey;

  /// [cap]까지 남은 크래커.
  /// [dailyCap]을 주면 하루 상한만 그 값으로 본다(레벨 보상, 5차 566).
  int remaining(RewardCap cap, {int? dailyCap}) => switch (cap) {
        RewardCap.day => (dailyCap ?? rewardDailyCap) - day,
        RewardCap.week => rewardWeeklyCap - week,
        RewardCap.month => rewardMonthlyCap - month,
      };

  /// 가장 빡빡한 상한. 셋 다 여유가 있으면 남은 수가 가장 작은 것.
  RewardCap tightestOf({int? dailyCap}) {
    var pick = RewardCap.day;
    for (final cap in RewardCap.values) {
      if (remaining(cap, dailyCap: dailyCap) <
          remaining(pick, dailyCap: dailyCap)) {
        pick = cap;
      }
    }
    return pick;
  }

  /// 지금 받을 수 있는 가장 큰 액수. 0이면 더 받을 수 없다.
  int get allowance => allowanceOf();

  /// [dailyCap]을 주면 하루 상한만 그 값으로 본다.
  int allowanceOf({int? dailyCap}) {
    var left = remaining(RewardCap.day, dailyCap: dailyCap);
    for (final cap in RewardCap.values) {
      final other = remaining(cap, dailyCap: dailyCap);
      if (other < left) left = other;
    }
    return left < 0 ? 0 : left;
  }

  /// 날짜가 바뀌면 그 칸을 0으로 돌린 장부.
  RewardLedger rolledOver(DateTime now) {
    final d = rewardDayKey(now);
    final w = rewardWeekKey(now);
    final m = rewardMonthKey(now);
    return RewardLedger(
      day: dayKey == d ? day : 0,
      week: weekKey == w ? week : 0,
      month: monthKey == m ? month : 0,
      dayKey: d,
      weekKey: w,
      monthKey: m,
    );
  }

  RewardLedger plus(int crackers) => RewardLedger(
        day: day + crackers,
        week: week + crackers,
        month: month + crackers,
        dayKey: dayKey,
        weekKey: weekKey,
        monthKey: monthKey,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'week': week,
        'month': month,
        'dayKey': dayKey,
        'weekKey': weekKey,
        'monthKey': monthKey,
      };

  static RewardLedger fromJson(Map<String, dynamic> json) => RewardLedger(
        day: (json['day'] as num?)?.toInt() ?? 0,
        week: (json['week'] as num?)?.toInt() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? 0,
        dayKey: json['dayKey'] as String? ?? '',
        weekKey: json['weekKey'] as String? ?? '',
        monthKey: json['monthKey'] as String? ?? '',
      );
}

/// '2026-11-18'.
String rewardDayKey(DateTime at) =>
    '${at.year}-${at.month.toString().padLeft(2, '0')}-'
    '${at.day.toString().padLeft(2, '0')}';

/// 월요일을 첫날로 보는 주. '2026-11-16'(그 주 월요일).
String rewardWeekKey(DateTime at) {
  final monday = DateTime(at.year, at.month, at.day - (at.weekday - 1));
  return rewardDayKey(monday);
}

/// '2026-11'.
String rewardMonthKey(DateTime at) =>
    '${at.year}-${at.month.toString().padLeft(2, '0')}';

// ── 기댓값 ────────────────────────────────────────────────────────────
//
// 상한이 있으면 '한 번 평균 × 횟수'가 아니다. 상한에 가까워질수록 깎이기
// 때문이다. 그래서 액수를 [rewardUnit] 칸으로 쪼개 분포를 직접 굴린다.
// 칸이 31개(하루)·151개(주)뿐이라 금방 끝난다.

/// 하루에 [rolls]번 연습했을 때 받는 크래커의 분포.
///
/// 돌려주는 목록의 i번째는 '$i * [rewardUnit] 크래커를 받을 확률'이다.
List<double> rewardDayDistribution(int rolls) {
  final cap = rewardDailyCap ~/ rewardUnit;
  var dist = List<double>.filled(cap + 1, 0)..[0] = 1;
  final total = rewardTotalWeight.toDouble();
  for (var n = 0; n < rolls; n++) {
    final next = List<double>.filled(cap + 1, 0);
    for (var sum = 0; sum <= cap; sum++) {
      final p = dist[sum];
      if (p == 0) continue;
      for (final tier in rewardTiers) {
        final to = min(cap, sum + tier.crackers ~/ rewardUnit);
        next[to] += p * tier.weight / total;
      }
    }
    dist = next;
  }
  return dist;
}

/// 분포를 [times]번 더한다. [capUnits] 칸을 넘으면 거기서 멈춘다.
List<double> _repeatCapped(List<double> one, int times, int capUnits) {
  var dist = List<double>.filled(capUnits + 1, 0)..[0] = 1;
  for (var t = 0; t < times; t++) {
    final next = List<double>.filled(capUnits + 1, 0);
    for (var sum = 0; sum <= capUnits; sum++) {
      final p = dist[sum];
      if (p == 0) continue;
      for (var add = 0; add < one.length; add++) {
        final q = one[add];
        if (q == 0) continue;
        next[min(capUnits, sum + add)] += p * q;
      }
    }
    dist = next;
  }
  return dist;
}

double _mean(List<double> dist) {
  var sum = 0.0;
  for (var i = 0; i < dist.length; i++) {
    sum += i * rewardUnit * dist[i];
  }
  return sum;
}

/// 하루에 [rolls]번 연습하는 사람이 받는 크래커.
///
/// [daysPerWeek]는 한 주에 연습하는 날수. 나머지 날은 0을 받는다.
/// 한 달은 4주(28일)로 본다.
class RewardForecast {
  const RewardForecast({
    required this.rollsPerDay,
    required this.daysPerWeek,
    required this.perPracticeDay,
    required this.perWeek,
    required this.perMonth,
  });

  final int rollsPerDay;
  final int daysPerWeek;

  /// 연습한 날 하루에 받는 기댓값.
  final double perPracticeDay;

  /// 한 주(7일) 기댓값. 주 상한을 지킨다.
  final double perWeek;

  /// 네 주(28일) 기댓값. 달 상한을 지킨다.
  final double perMonth;

  /// 패롯으로 몇 개어치인가. 패롯 1 = 크래커 1,000.
  double get parrotsPerMonth => perMonth / 1000;
}

/// 하루에 [rollsPerDay]번, 한 주에 [daysPerWeek]일 연습할 때의 기댓값.
RewardForecast rewardForecast({
  required int rollsPerDay,
  int daysPerWeek = 7,
}) {
  final day = rewardDayDistribution(rollsPerDay);
  final week = _repeatCapped(
      day, daysPerWeek.clamp(0, 7), rewardWeeklyCap ~/ rewardUnit);
  final month = _repeatCapped(week, 4, rewardMonthlyCap ~/ rewardUnit);
  return RewardForecast(
    rollsPerDay: rollsPerDay,
    daysPerWeek: daysPerWeek,
    perPracticeDay: _mean(day),
    perWeek: _mean(week),
    perMonth: _mean(month),
  );
}

// ── 글귀 ──────────────────────────────────────────────────────────────
//
// 액수를 뽑기 때문에 '크래커 30개를 줘요'라고 미리 적을 수 없다. 예약 알림은
// 더 그렇다. 며칠 전에 깔아 둔 알림은 그날 몇 개를 뽑을지 모른다. 그래서
// 알림과 화면이 같은 말을 쓰고, 수는 받은 뒤에만 적는다.

/// 1,000 단위에 쉼표를 넣는다.
String rewardCrackerCount(int crackers) {
  final digits = crackers.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${crackers < 0 ? '-' : ''}$buffer';
}

/// 알림 본문에 한 줄로 붙이는 말. 예약 알림은 그날 몇 개를 뽑을지 모른다.
const String practiceRewardShortInvite = '따라 말하면 크래커를 받아요';

/// 연습 알림과 화면이 함께 쓰는 말. 수는 말하지 않는다.
String get practiceRewardInvite =>
    '따라 말하면 크래커를 받아요. 많게는 ${rewardCrackerCount(rewardMaxCrackers)}개까지요.';

/// 받은 뒤에 보여 주는 말.
String practiceRewardEarned(int crackers) =>
    '크래커 +${rewardCrackerCount(crackers)}';

/// 상한에 걸려 더 줄 수 없을 때. 막힌 까닭을 누르기 전에도 이 말로 적는다.
String practiceRewardCappedMessage(RewardCap cap) =>
    '${cap.label} 받을 크래커를 다 받았어요. '
    '${cap.label}는 ${rewardCrackerCount(cap.limit)}개까지예요.';

/// 설정·안내에서 상한을 한 줄로.
String get practiceRewardCapSummary =>
    '하루 ${rewardCrackerCount(rewardDailyCap)}개, '
    '한 주 ${rewardCrackerCount(rewardWeeklyCap)}개, '
    '한 달 ${rewardCrackerCount(rewardMonthlyCap)}개까지 받아요.';
