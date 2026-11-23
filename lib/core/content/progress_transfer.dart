// 학습 진도를 백업에 담고 되돌리는 길(5차 566).
//
// 백업 zip은 클립 DB·영상과 문장·단어 글만 담았다. 친밀도, 캐릭터 XP,
// 단어 복습 진도, 연습 달력은 모두 SharedPreferences에 있는데 그것은
// `Library/Preferences`에 있고 백업은 `Documents`만 훑는다. 그래서
// 기기를 바꿔 복원하면 **문장은 돌아오고 익힌 기록은 처음부터**였다.
//
// 담는 것은 진도뿐이다. 알림 시각이나 재생 속도 같은 기기 설정은
// 새 기기에서 그 기기대로 두는 편이 낫고, 구글 드라이브 폴더 id처럼
// 계정에 매인 값은 옮기면 오히려 엉킨다.
//
// 키에는 계정 id가 박혀 있다(`...v1.<uid>`). 다른 계정으로 복원하면
// 그 키는 쓰이지 않고 남는다 - 지우지 않으므로 손실은 없다.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 백업 zip 안 진도 파일 이름.
const String progressDataFileName = 'progress.json';

/// 문장과 함께 담을 키 앞머리.
///
/// 하나하나 적는다. `parrokit.` 전부를 담으면 알림 설정과 본 적 있는
/// 안내 표시까지 따라가, 새 기기에서 끈 알림이 되살아난다.
const List<String> sentenceProgressPrefixes = [
  // 문장별 친밀도·연습·듣기·메모·좋아요
  'parrokit.sentence_activity.v1.',
  // 캐릭터 XP와 레벨 보따리
  'parrokit.parrot.xp.v2.',
  'parrokit.parrot.xp_day.v1.',
  'parrokit.parrot.level_rewards.v1.',
  // 옛 XP. 연습 달력이 '예전 누적 문장 수'로도 읽는다.
  'parrokit.speaking.xp.v1.',
  // 연습 기록과 달력
  'parrokit.practice_log.v1.',
  'parrokit.practice.daily_goal.v1.',
  'parrokit.practice.goals.v1.',
  'parrokit.practice.history.v1.',
  'parrokit.practice.total.v1.',
  // 크래커 하루·주·달 상한을 센 장부. 안 담으면 복원한 기기에서
  // 오늘 몫이 비어 상한을 한 번 더 받는다.
  'parrokit.practice_reward.ledger.v1.',
];

/// 단어와 함께 담을 키 앞머리.
const List<String> wordProgressPrefixes = [
  // 간격 반복 복습 진도
  'parrokit.word_reviews.v1.',
  // 달력의 단어 기록
  'parrokit.practice.word_history.v1.',
];

/// 담을 수 있는 모든 키 앞머리.
List<String> get progressKeyPrefixes =>
    [...sentenceProgressPrefixes, ...wordProgressPrefixes];

/// 이 키를 백업에 담는지. 고른 갈래에 든 것만 담는다.
bool isProgressKey(String key, {bool sentences = true, bool words = true}) {
  bool matches(List<String> prefixes) =>
      prefixes.any((prefix) => key.startsWith(prefix));
  if (sentences && matches(sentenceProgressPrefixes)) return true;
  if (words && matches(wordProgressPrefixes)) return true;
  return false;
}

/// 값에 종류를 붙여 적는다.
///
/// JSON만으로는 3과 3.0을 가릴 수 없다. 되돌릴 때 int가 double로
/// 바뀌면 SharedPreferences가 다른 칸에 넣어 읽을 수 없게 된다.
Map<String, Object?>? encodeProgressValue(Object? value) {
  if (value is bool) return {'t': 'bool', 'v': value};
  if (value is int) return {'t': 'int', 'v': value};
  if (value is double) return {'t': 'double', 'v': value};
  if (value is String) return {'t': 'string', 'v': value};
  if (value is List<String>) return {'t': 'strings', 'v': value};
  // 모르는 종류는 담지 않는다. 되돌릴 수 없는 것을 담으면 복원이 넘어진다.
  return null;
}

/// [encodeProgressValue]가 적은 것을 되돌린다. 못 읽으면 null.
Object? decodeProgressValue(Object? entry) {
  if (entry is! Map) return null;
  final value = entry['v'];
  switch (entry['t']) {
    case 'bool':
      return value is bool ? value : null;
    case 'int':
      return value is num ? value.toInt() : null;
    case 'double':
      return value is num ? value.toDouble() : null;
    case 'string':
      return value is String ? value : null;
    case 'strings':
      if (value is! List) return null;
      return [
        for (final one in value)
          if (one is String) one
      ];
    default:
      return null;
  }
}

/// 지금 기기의 진도를 글로 만든다. 담을 것이 없으면 null.
Future<String?> exportProgress({
  SharedPreferences? prefs,
  bool sentences = true,
  bool words = true,
}) async {
  final SharedPreferences store;
  try {
    store = prefs ?? await SharedPreferences.getInstance();
  } catch (_) {
    return null;
  }
  final values = <String, Object?>{};
  for (final key in store.getKeys()) {
    if (!isProgressKey(key, sentences: sentences, words: words)) continue;
    final encoded = encodeProgressValue(store.get(key));
    if (encoded != null) values[key] = encoded;
  }
  if (values.isEmpty) return null;
  return jsonEncode({'version': 1, 'values': values});
}

/// 백업에서 읽은 진도를 이 기기에 적는다. 적은 칸 수를 돌려준다.
///
/// 백업에 없는 키는 **지우지 않는다**. 복원은 되돌리는 일이지 지우는
/// 일이 아니고, 지우면 복원 뒤에 생긴 기록까지 날아간다.
Future<int> importProgress(
  String raw, {
  SharedPreferences? prefs,
  bool sentences = true,
  bool words = true,
}) async {
  final Map<String, dynamic> values;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return 0;
    final body = decoded['values'];
    if (body is! Map) return 0;
    values = Map<String, dynamic>.from(body);
  } catch (_) {
    return 0;
  }

  final SharedPreferences store;
  try {
    store = prefs ?? await SharedPreferences.getInstance();
  } catch (_) {
    return 0;
  }

  var written = 0;
  for (final entry in values.entries) {
    if (!isProgressKey(entry.key, sentences: sentences, words: words)) {
      continue;
    }
    final value = decodeProgressValue(entry.value);
    if (value == null) continue;
    try {
      final ok = switch (value) {
        final bool v => await store.setBool(entry.key, v),
        final int v => await store.setInt(entry.key, v),
        final double v => await store.setDouble(entry.key, v),
        final String v => await store.setString(entry.key, v),
        final List<String> v => await store.setStringList(entry.key, v),
        _ => false,
      };
      if (ok) written++;
    } catch (_) {
      // 한 칸을 못 적어도 나머지는 되돌린다.
    }
  }
  return written;
}
