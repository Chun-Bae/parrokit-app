// 날마다 몇 문장을 따라 말했는지 적어 두는 곳(홈 '학습 캘린더', 5차).
//
// 전에는 홈 무대 화면이 이 기록을 혼자 들고 있어서, **보관함 문장 창에서
// 따라 말하기를 하면 캘린더에 안 쌓였다.** 바로 위 '내 문장 기록'에는
// '어제 · 따라 말하기 2회'라고 적혀 있는데 캘린더는 '학습 0일'이라
// 어긋나 보였다. 적는 곳을 꺼내 두 화면이 같이 쓴다.
//
// 저장 자리(SharedPreferences 키)와 모양은 예전 그대로라 전에 쌓은 기록을
// 그대로 읽는다.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 하루치 기록을 읽어 온 값.
class PracticeCalendarData {
  const PracticeCalendarData({
    required this.counts,
    required this.goals,
    required this.total,
    required this.dailyGoal,
    this.wordCounts = const {},
  });

  /// 날짜(yyyy-MM-dd) → 그날 따라 말한 문장 수.
  final Map<String, int> counts;

  /// 날짜(yyyy-MM-dd) → 그날 복습한 단어 수(사용자 요청).
  ///
  /// 따라 말하기와 따로 센다. 하루 목표와 칸 색은 지금처럼 따라 말한 수만
  /// 보므로, 단어를 많이 복습했다고 '목표 완료'가 되지는 않는다.
  final Map<String, int> wordCounts;

  /// 날짜 → 그날의 목표. 목표를 바꿔도 지난 날은 그때 목표로 본다.
  final Map<String, int> goals;

  /// 처음부터 지금까지 따라 말한 문장 수.
  final int total;

  /// 지금 정해 둔 하루 목표.
  final int dailyGoal;
}

class PracticeCalendar {
  const PracticeCalendar._();

  static const int defaultDailyGoal = 5;

  /// 기록이 쌓일 때마다 오른다. 홈 캘린더가 이 값을 보고 다시 읽는다
  /// (5차 351). 전에는 홈이 계정마다 한 번만 읽어서, 보관함에서 따라 말하면
  /// 앱을 다시 켤 때까지 '학습 0일'로 남았다.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// 하루 목표. 홈의 '목표 바꾸기'가 적는 자리와 같아야 한다(5차 351).
  /// 전에는 여기만 다른 이름을 봐서, 보관함에서 따라 말하면 그날 목표가
  /// 사용자가 정한 값이 아니라 늘 기본값 5로 적혔다.
  static String goalKey(String accountId) =>
      'parrokit.practice.daily_goal.v1.$accountId';
  static String historyKey(String accountId) =>
      'parrokit.practice.history.v1.$accountId';
  static String goalsKey(String accountId) =>
      'parrokit.practice.goals.v1.$accountId';
  static String totalKey(String accountId) =>
      'parrokit.practice.total.v1.$accountId';

  /// 날짜별 단어 복습 수. 따라 말하기 기록과 다른 자리에 둔다.
  static String wordHistoryKey(String accountId) =>
      'parrokit.practice.word_history.v1.$accountId';

  static Map<String, int> _decodeCounts(String? raw, {int max = 1000}) {
    if (raw == null) return {};
    final out = <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is num && value >= 1 && value <= max) {
            out[entry.key] = value.toInt();
          }
        }
      }
    } catch (_) {
      // 깨진 기록은 버린다. 다음 연습부터 다시 쌓인다.
    }
    return out;
  }

  /// 숫자 하나를 안전하게 읽는다(5차 453).
  ///
  /// `getInt`는 저장된 값이 double이면 타입 오류를 **던진다**. XP 자리는
  /// 지금 double로 적히는데 아래에서 getInt로 읽고 있어서, load가 통째로
  /// 넘어졌다. 그러면 recordOne도 함께 넘어져 **따라 말하기를 해도 학습
  /// 캘린더에 하나도 쌓이지 않았다**('학습 0일 · 누적 0문장').
  static int? _readInt(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    return value is num ? value.toInt() : null;
  }

  static Future<PracticeCalendarData> load(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeCounts(prefs.getString(historyKey(accountId)));
    final goals = _decodeCounts(prefs.getString(goalsKey(accountId)), max: 100);
    final wordCounts =
        _decodeCounts(prefs.getString(wordHistoryKey(accountId)));
    // 예전에는 XP 자리에 누적 문장 수를 적었다. 그 값도 읽어 준다.
    // 지금 그 자리에는 double이 들어 있으므로 숫자로만 받아 본다.
    final legacyTotal =
        _readInt(prefs, 'parrokit.speaking.xp.v1.$accountId') ?? 0;
    return PracticeCalendarData(
      counts: counts,
      goals: goals,
      wordCounts: wordCounts,
      total: _readInt(prefs, totalKey(accountId)) ?? legacyTotal,
      dailyGoal: (_readInt(prefs, goalKey(accountId)) ?? defaultDailyGoal)
          .clamp(1, 100),
    );
  }

  /// 하루 목표를 바꾼다. 오늘 자리의 목표도 함께 바꾼다(5차 352).
  ///
  /// 적는 자리를 화면마다 적지 않게 여기 둔다. 전에는 홈이 제 키를 들고
  /// 있어서 이 파일과 어긋났고, 보관함에서 따라 말하면 그날 목표가 기본값으로
  /// 적혔다(5차 351).
  static Future<PracticeCalendarData> setDailyGoal(
    String accountId,
    int goal, {
    DateTime? now,
  }) async {
    final next = goal.clamp(1, 100);
    final data = await load(accountId);
    final goals = Map<String, int>.from(data.goals);
    goals[dateKey(now ?? DateTime.now())] = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setInt(goalKey(accountId), next),
        prefs.setString(goalsKey(accountId), jsonEncode(goals)),
      ]);
    } catch (_) {
      // 지금 화면에서는 바뀐 목표를 그대로 쓴다.
    }
    revision.value++;

    return PracticeCalendarData(
      counts: data.counts,
      goals: goals,
      wordCounts: data.wordCounts,
      total: data.total,
      dailyGoal: next,
    );
  }

  /// 따라 말하기 한 문장을 오늘 자리에 더한다. 어느 화면에서 했든 같다.
  ///
  /// 돌려주는 값은 더한 뒤의 기록이다. 저장에 실패해도 더한 값을 돌려주어
  /// 화면이 바로 반영할 수 있게 한다.
  static Future<PracticeCalendarData> recordOne(
    String accountId, {
    DateTime? now,
  }) async {
    final data = await load(accountId);
    final key = dateKey(now ?? DateTime.now());
    final counts = Map<String, int>.from(data.counts);
    final goals = Map<String, int>.from(data.goals);
    counts[key] = (counts[key] ?? 0) + 1;
    goals.putIfAbsent(key, () => data.dailyGoal);
    final total = data.total + 1;

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(historyKey(accountId), jsonEncode(counts)),
        prefs.setString(goalsKey(accountId), jsonEncode(goals)),
        prefs.setInt(totalKey(accountId), total),
      ]);
    } catch (_) {
      // 지금 화면 기록은 살리고 다음에 다시 저장해 본다.
    }
    revision.value++;

    return PracticeCalendarData(
      counts: counts,
      goals: goals,
      wordCounts: data.wordCounts,
      total: total,
      dailyGoal: data.dailyGoal,
    );
  }

  /// 단어 하나를 복습한 것을 오늘 자리에 더한다(사용자 요청).
  ///
  /// 따라 말하기와 섞지 않는다. 하루 목표는 따라 말한 수로 재는데, 단어
  /// 복습까지 그 수에 넣으면 단어만 넘겨도 '목표 완료'가 되어 버린다.
  /// 캘린더는 두 수를 나란히 적는다.
  ///
  /// 돌려주는 값은 더한 뒤의 기록이다. 저장에 실패해도 더한 값을 돌려주어
  /// 화면이 바로 반영할 수 있게 한다.
  static Future<PracticeCalendarData> recordWordReview(
    String accountId, {
    DateTime? now,
  }) async {
    final data = await load(accountId);
    final key = dateKey(now ?? DateTime.now());
    final wordCounts = Map<String, int>.from(data.wordCounts);
    wordCounts[key] = (wordCounts[key] ?? 0) + 1;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          wordHistoryKey(accountId), jsonEncode(wordCounts));
    } catch (_) {
      // 지금 화면 기록은 살리고 다음에 다시 저장해 본다.
    }
    revision.value++;

    return PracticeCalendarData(
      counts: data.counts,
      goals: data.goals,
      wordCounts: wordCounts,
      total: data.total,
      dailyGoal: data.dailyGoal,
    );
  }
}
