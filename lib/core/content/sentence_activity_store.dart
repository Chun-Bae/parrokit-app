import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sentence_mastery.dart';

class SentenceActivity {
  const SentenceActivity({
    this.parrotSpeakCount = 0,
    this.practiceCount = 0,
    this.practicePoints,
    this.listenCount = 0,
    this.listenPoints,
    this.lastPracticedAt,
    this.routineEnabled = true,
    this.liked = false,
    this.memo = '',
    this.dayKey,
    this.dayPoints = 0,
    this.listenDayPoints = 0,
    this.topLevel,
  });

  final int parrotSpeakCount;
  final int practiceCount;

  /// 따라 말하기로 쌓은 점수. 잘 따라 할수록 많이 쌓인다(100점 2점, 50점 1점).
  ///
  /// 예전 기록에는 이 값이 없다. 그때는 횟수당 2점으로 보던 때라
  /// [practiceScore]가 `practiceCount * 2`로 읽는다(5차).
  final int? practicePoints;

  /// 숙련도·친밀도에 쓰는 따라 말하기 점수.
  int get practiceScore => practicePoints ?? practiceCount * 2;

  /// 듣기 모드에서 앵무새 음성을 끝까지 들은 횟수.
  ///
  /// 이것은 **들은 횟수 그대로**다. 하루 상한을 걸지 않는다 - 기록
  /// 화면의 '듣기 N회'와 '듣기 횟수 기록' 스위치가 가리키는 수이고,
  /// 상한에 묶으면 하루 두 번 넘게 들은 사람에게 거짓말이 된다(5차 566).
  final int listenCount;

  /// 그 가운데 친밀도에 더해 준 몫. 없으면 [listenCount]로 본다.
  ///
  /// 듣기는 자동 재생이라 한 문장이 하루에 수십 번 울린다. 점수만
  /// 하루 [sentenceDailyListenCap]점으로 끊고, 들은 횟수는 그대로 센다.
  /// 예전 기록에는 이 값이 없고, 그때는 횟수가 곧 점수였다.
  final int? listenPoints;

  /// 친밀도에 쓰는 듣기 점수.
  int get listenScore => listenPoints ?? listenCount;

  /// 따라 말하기를 마지막으로 완료한 시각. 한 번도 안 했으면 null.
  final DateTime? lastPracticedAt;
  final bool routineEnabled;

  /// 이 문장에 좋아요를 눌렀는지. 서버가 없어서 이 기기에만 저장한다.
  final bool liked;

  /// 이 문장에 대한 내 메모. 이 기기에만 저장한다.
  final String memo;

  /// 오늘 몫을 센 날. 날이 바뀌면 센 것은 0으로 본다.
  final String? dayKey;

  /// 오늘 이 문장에서 쌓은 점수(듣기 포함).
  final int dayPoints;

  /// 그 가운데 듣기로 쌓은 점수.
  final int listenDayPoints;

  /// 캐릭터 XP를 이미 준 최고 단계.
  ///
  /// 없으면 지금 단계까지는 이미 준 것으로 본다(5차 566). 이게 없으면
  /// 예전 사용자가 앱을 켜는 순간 쌓아 둔 모든 단계의 XP를 한꺼번에 받아
  /// 레벨이 폭발한다.
  final int? topLevel;

  /// 오늘 쌓은 점수. 날이 바뀌었으면 0이다.
  int pointsToday(DateTime now) =>
      dayKey == sentenceDayKey(now) ? dayPoints : 0;

  /// 오늘 듣기로 쌓은 점수. 날이 바뀌었으면 0이다.
  int listenPointsToday(DateTime now) =>
      dayKey == sentenceDayKey(now) ? listenDayPoints : 0;

  SentenceActivity copyWith({
    int? parrotSpeakCount,
    int? practiceCount,
    int? practicePoints,
    int? listenCount,
    int? listenPoints,
    DateTime? lastPracticedAt,
    bool? routineEnabled,
    bool? liked,
    String? memo,
    String? dayKey,
    int? dayPoints,
    int? listenDayPoints,
    int? topLevel,
  }) =>
      SentenceActivity(
        parrotSpeakCount: parrotSpeakCount ?? this.parrotSpeakCount,
        practiceCount: practiceCount ?? this.practiceCount,
        practicePoints: practicePoints ?? this.practicePoints,
        listenCount: listenCount ?? this.listenCount,
        listenPoints: listenPoints ?? this.listenPoints,
        lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
        routineEnabled: routineEnabled ?? this.routineEnabled,
        liked: liked ?? this.liked,
        memo: memo ?? this.memo,
        dayKey: dayKey ?? this.dayKey,
        dayPoints: dayPoints ?? this.dayPoints,
        listenDayPoints: listenDayPoints ?? this.listenDayPoints,
        topLevel: topLevel ?? this.topLevel,
      );

  Map<String, Object> toJson() => {
        if (lastPracticedAt != null)
          'lastPracticedAt': lastPracticedAt!.millisecondsSinceEpoch,
        'parrotSpeakCount': parrotSpeakCount,
        'practiceCount': practiceCount,
        if (practicePoints != null) 'practicePoints': practicePoints!,
        'listenCount': listenCount,
        if (listenPoints != null) 'listenPoints': listenPoints!,
        'routineEnabled': routineEnabled,
        if (liked) 'liked': true,
        if (memo.isNotEmpty) 'memo': memo,
        if (dayKey != null) 'dayKey': dayKey!,
        if (dayPoints > 0) 'dayPoints': dayPoints,
        if (listenDayPoints > 0) 'listenDayPoints': listenDayPoints,
        if (topLevel != null) 'topLevel': topLevel!,
      };

  factory SentenceActivity.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const SentenceActivity();
    return SentenceActivity(
      parrotSpeakCount:
          (value['parrotSpeakCount'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      practiceCount:
          (value['practiceCount'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      practicePoints:
          (value['practicePoints'] as num?)?.clamp(0, 1 << 31).toInt(),
      listenCount:
          (value['listenCount'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      listenPoints:
          (value['listenPoints'] as num?)?.clamp(0, 1 << 31).toInt(),
      lastPracticedAt: switch (value['lastPracticedAt']) {
        final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        _ => null,
      },
      routineEnabled: value['routineEnabled'] as bool? ?? true,
      liked: value['liked'] as bool? ?? false,
      memo: value['memo'] as String? ?? '',
      dayKey: value['dayKey'] as String?,
      dayPoints: (value['dayPoints'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      listenDayPoints:
          (value['listenDayPoints'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      topLevel: (value['topLevel'] as num?)?.clamp(0, 99).toInt(),
    );
  }
}

/// 따라 말하기 한 번이 친밀도에 더하는 점수(5차 566).
///
/// 전에는 0/1/2였다. 25점 미만이면 0점이라 "했는데 아무것도 안 쌓였다"가
/// 됐고, 그 순간 홈 헤더는 '+0.1 XP'라고 적어 한 화면에서 말이 갈렸다.
/// 1/2/3으로 두면 어떤 완료든 반드시 1점은 쌓이고, 잘한 것과 그냥 넘긴
/// 것의 격차는 두 배에서 세 배로 벌어진다.
int practiceGain(double? score) {
  if (score == null) return 1; // 체크로 넘김 = 노력 하한
  final value = score.clamp(0.0, 1.0);
  if (value >= 0.85) return 3;
  if (value >= 0.60) return 2;
  return 1;
}

/// 한 문장이 하루에 받을 수 있는 친밀도 점수.
///
/// 하루 목표 기본값이 5번이다. 6점이면 5번을 한 문장에 몰아줘도 이득이
/// 없어 자연스럽게 두세 문장으로 퍼진다. 넘겨도 연습을 막지는 않는다 -
/// 크래커와 하루 목표는 그대로 센다.
const int sentenceDailyPointCap = 6;

/// 오늘 이 문장의 몫을 다 썼을 때 적는 말.
const String sentenceDayFullMessage = '오늘은 이 문장을 충분히 익혔어요';

/// 그 가운데 듣기로 받을 수 있는 몫.
///
/// 홈 무대는 자동 재생이라 한 문장이 하루에 수십 번 울린다. 상한이 없어서
/// **켜 두기만 해도 최고 단계**에 닿았다. 2점이면 듣기만으로 50점까지
/// 25일, 잘 말하면 9일이라 말하기가 빠른 길이 된다.
const int sentenceDailyListenCap = 2;

/// '듣기 횟수 기록' 스위치 아래 적는 말(5차 567).
///
/// 이 스위치는 **홈 무대의 자동 재생에만** 걸린다. 문장 창에서 직접
/// 스피커를 누른 것은 설정과 상관없이 그대로 센다. 전에는 '앵무새 말을
/// 끝까지 들어도 듣기 횟수가 오르지 않아요'라고만 적어, 꺼 두면 어디서
/// 들어도 안 센다고 읽혔다. 친밀도도 함께 멎는다는 말도 없었다.
const String countListenHint =
    '끄면 앵무새가 말할 때는 듣기 횟수와 친밀도가 오르지 않아요. '
    '문장 창에서 직접 들은 것은 그대로 쌓여요.';

/// 오늘 이 문장에 남은 친밀도 몫. 다 썼으면 0이다.
int sentenceRoomToday(SentenceActivity activity, {DateTime? now}) {
  final at = now ?? DateTime.now();
  return (sentenceDailyPointCap - activity.pointsToday(at))
      .clamp(0, sentenceDailyPointCap);
}

/// 오늘 듣기로 더 받을 수 있는 몫. 문장 전체 몫보다 클 수 없다.
int sentenceListenRoomToday(SentenceActivity activity, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final listenRoom =
      (sentenceDailyListenCap - activity.listenPointsToday(at)).clamp(0, sentenceDailyListenCap);
  return listenRoom.clamp(0, sentenceRoomToday(activity, now: at));
}

/// 하루를 가르는 열쇠. 한국 자정 기준으로 앱의 다른 하루치와 같다.
String sentenceDayKey(DateTime now) {
  final kst = now.toUtc().add(const Duration(hours: 9));
  return '${kst.year}-${kst.month}-${kst.day}';
}

/// 따라 말하기 한 번의 결과. 화면이 이것으로 안내와 XP를 정한다.
class SentencePracticeResult {
  const SentencePracticeResult({
    required this.gained,
    required this.dayFull,
    this.leveledTo,
    this.xp = 0,
  });

  /// 이번에 쌓인 친밀도 점수. 오늘 몫을 다 썼으면 0이다.
  final int gained;

  /// 오늘 이 문장의 몫을 다 썼는지.
  final bool dayFull;

  /// 이번에 오른 단계. 안 올랐으면 null.
  final int? leveledTo;

  /// 단계가 올라서 받는 캐릭터 XP.
  final int xp;
}

class SentenceActivityStore {
  SentenceActivityStore._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 듣기·말하기·연습 횟수가 바뀔 때마다 오른다. 기록 화면이 실시간으로 갱신하는 데 쓴다.
  static final ValueNotifier<int> activityRevision = ValueNotifier<int>(0);

  static String _key(String accountId) =>
      'parrokit.sentence_activity.v1.$accountId';

  static Future<Map<String, SentenceActivity>> loadAll(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(accountId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          entry.key: SentenceActivity.fromJson(entry.value),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<SentenceActivity> load(
    String accountId,
    String sentenceId,
  ) async {
    final all = await loadAll(accountId);
    return all[sentenceId] ?? const SentenceActivity();
  }

  static Future<void> incrementParrotSpeak(
    String accountId,
    String sentenceId,
  ) =>
      _update(
        accountId,
        sentenceId,
        (activity) => activity.copyWith(
          parrotSpeakCount: activity.parrotSpeakCount + 1,
        ),
      );

  /// 따라 말하기 한 번을 기록한다. [score](0~1)가 높을수록 많이 오른다.
  ///
  /// 하루에 이 문장에서 받을 수 있는 점수는 [sentenceDailyPointCap]까지다
  /// (5차 566). 넘겨도 연습 횟수와 마지막 연습 시각은 그대로 적는다 -
  /// 크래커와 하루 목표는 계속 센다.
  ///
  /// 돌려주는 값으로 화면이 '오늘 몫을 다 채웠다'와 단계 상승을 안다.
  static Future<SentencePracticeResult> incrementPractice(
    String accountId,
    String sentenceId, {
    double? score,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final day = sentenceDayKey(at);
    var result = const SentencePracticeResult(gained: 0, dayFull: false);
    await _update(
      accountId,
      sentenceId,
      (activity) {
        final today = activity.pointsToday(at);
        final room = sentenceDailyPointCap - today;
        final gained = practiceGain(score).clamp(0, room < 0 ? 0 : room);
        final before = affinityOf(activity).level;
        final next = activity.copyWith(
          practiceCount: activity.practiceCount + 1,
          practicePoints: activity.practiceScore + gained,
          lastPracticedAt: at,
          dayKey: day,
          dayPoints: today + gained,
          listenDayPoints: activity.listenPointsToday(at),
        );
        final after = affinityOf(next).level;
        final from = activity.topLevel ?? before;
        result = SentencePracticeResult(
          gained: gained,
          dayFull: gained == 0,
          leveledTo: after > before ? after : null,
          xp: affinityXpBetween(from, after),
        );
        return after > from ? next.copyWith(topLevel: after) : next;
      },
    );
    return result;
  }

  /// 끝까지 들은 것을 기록한다.
  ///
  /// 홈 무대는 자동 재생이라 한 문장이 하루에 수십 번 울린다. 친밀도
  /// 점수는 하루 [sentenceDailyListenCap]점까지만 받는다(5차 566).
  /// 들은 횟수 자체는 그대로 센다 - 기록 화면이 그 수를 보여 준다.
  static Future<void> incrementListen(
    String accountId,
    String sentenceId, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final day = sentenceDayKey(at);
    return _update(
      accountId,
      sentenceId,
      (activity) {
        final listenToday = activity.listenPointsToday(at);
        final today = activity.pointsToday(at);
        final allowed = listenToday < sentenceDailyListenCap &&
            today < sentenceDailyPointCap;
        return activity.copyWith(
          // 들은 횟수는 언제나 센다. 상한은 친밀도 점수에만 건다.
          listenCount: activity.listenCount + 1,
          listenPoints: activity.listenScore + (allowed ? 1 : 0),
          dayKey: day,
          dayPoints: today + (allowed ? 1 : 0),
          listenDayPoints: listenToday + (allowed ? 1 : 0),
        );
      },
    );
  }

  static Future<void> setRoutineEnabled(
    String accountId,
    String sentenceId,
    bool enabled,
  ) =>
      _update(
        accountId,
        sentenceId,
        (activity) => activity.copyWith(routineEnabled: enabled),
        notifyRoutine: true,
      );

  static Future<void> setLiked(
    String accountId,
    String sentenceId,
    bool liked,
  ) =>
      _update(
        accountId,
        sentenceId,
        (activity) => activity.copyWith(liked: liked),
      );

  /// 빈 문자열이면 메모를 지운다.
  static Future<void> setMemo(
    String accountId,
    String sentenceId,
    String memo,
  ) =>
      _update(
        accountId,
        sentenceId,
        (activity) => activity.copyWith(memo: memo.trim()),
      );

  static Future<void> _update(
    String accountId,
    String sentenceId,
    SentenceActivity Function(SentenceActivity current) update, {
    bool notifyRoutine = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll(accountId);
    final current = all[sentenceId] ?? const SentenceActivity();
    all[sentenceId] = update(current);
    await prefs.setString(
      _key(accountId),
      jsonEncode({
        for (final entry in all.entries) entry.key: entry.value.toJson(),
      }),
    );
    activityRevision.value++;
    if (notifyRoutine) revision.value++;
  }
}
