// 하루에 한 번만 주는 성취 XP를 적어 두는 곳(5차 566, 사용자 요청).
//
// XP는 반복이 아니라 **한 번만 생기는 일**에 붙는다. 같은 일로 두 번
// 받지 않으려면 오늘 무엇을 이미 줬는지 적어 둬야 한다. 날이 바뀌면
// 적어 둔 것은 없는 것으로 본다.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'speaking_xp.dart';

/// 하루 첫 따라 말하기.
///
/// 첫 레벨업이 그날 안에 일어나야 한다. 이것(2) + 목표 달성(6) + 문장
/// 한 단계(2)면 Lv.1을 넘는 10 XP가 된다.
const int firstPracticeXp = 2;

/// 하루 목표를 채웠을 때. 하루에 가장 큰 한 덩이다.
const int dailyGoalXp = 6;

/// 하루 첫 단어 복습 묶음(10개).
const int firstWordsXp = 3;

/// 몇 개를 풀면 한 묶음으로 보는지.
const int wordReviewXpCount = 10;

/// 하루를 가르는 열쇠. 한국 자정 기준으로 앱의 다른 하루치와 같다.
String parrotXpDay(DateTime now) {
  final kst = now.toUtc().add(const Duration(hours: 9));
  return '${kst.year}-${kst.month}-${kst.day}';
}

/// 오늘 이미 준 성취들.
class ParrotXpDay {
  ParrotXpDay._();

  static String key(String accountId) =>
      'parrokit.parrot.xp_day.v1.$accountId';

  static Future<Map<String, dynamic>> _read(
      SharedPreferences prefs, String accountId, DateTime now) async {
    try {
      final raw = prefs.getString(key(accountId));
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      // 날이 바뀌었으면 어제 적어 둔 것은 없는 것으로 본다.
      if (decoded['day'] != parrotXpDay(now)) return {};
      return decoded;
    } catch (_) {
      return {};
    }
  }

  /// [what]을 오늘 처음 한 것이면 적어 두고 true를 돌려준다.
  ///
  /// 이미 적혀 있으면 false다. 못 적으면 false로 둔다 - 못 적은 채
  /// true를 주면 앱을 다시 켤 때마다 같은 XP를 또 받는다.
  static Future<bool> claim(
    String accountId,
    String what, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = await _read(prefs, accountId, at);
      if (today[what] == true) return false;
      final next = {...today, 'day': parrotXpDay(at), what: true};
      return prefs.setString(key(accountId), jsonEncode(next));
    } catch (_) {
      return false;
    }
  }
}

/// 하루 첫 따라 말하기면 적어 두고 true. 두 번째부터는 false다.
Future<bool> markFirstPracticeToday(String accountId, {DateTime? now}) =>
    ParrotXpDay.claim(accountId, 'firstPractice', now: now);

/// 오늘 하루 목표를 처음 채운 것이면 적어 두고 true.
Future<bool> markDailyGoalToday(String accountId, {DateTime? now}) =>
    ParrotXpDay.claim(accountId, 'goal', now: now);

/// 오늘 단어 복습 묶음을 처음 끝낸 것이면 적어 두고 true.
Future<bool> markFirstWordsToday(String accountId, {DateTime? now}) =>
    ParrotXpDay.claim(accountId, 'words', now: now);

/// 성취 XP를 더한다. 쌓인 값을 돌려주고, 저장에 실패하면 null.
Future<int?> grantParrotXp(String accountId, int gain) =>
    addParrotXp(accountId, gain);
