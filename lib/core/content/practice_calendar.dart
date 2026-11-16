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
  });

  /// 날짜(yyyy-MM-dd) → 그날 따라 말한 문장 수.
  final Map<String, int> counts;

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

  static Future<PracticeCalendarData> load(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeCounts(prefs.getString(historyKey(accountId)));
    final goals = _decodeCounts(prefs.getString(goalsKey(accountId)), max: 100);
    // 예전에는 XP 자리에 누적 문장 수를 적었다. 그 값도 읽어 준다.
    final legacyTotal = prefs.getInt('parrokit.speaking.xp.v1.$accountId') ?? 0;
    return PracticeCalendarData(
      counts: counts,
      goals: goals,
      total: prefs.getInt(totalKey(accountId)) ?? legacyTotal,
      dailyGoal:
          (prefs.getInt(goalKey(accountId)) ?? defaultDailyGoal).clamp(1, 100),
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
      total: total,
      dailyGoal: data.dailyGoal,
    );
  }
}
