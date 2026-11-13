import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'my_word_store.dart';

/// 단어 하나의 복습 상태.
class WordReview {
  const WordReview({this.step = 0, this.dueAt, this.lastReviewedAt});

  /// 몇 번 연달아 "알아요"를 했는지. 0이면 새 단어거나 "다시"를 누른 단어.
  final int step;

  /// 이 시각이 지나면 오늘 다시 볼 단어다. 없으면 바로 볼 단어(새 단어).
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;
}

/// "오늘 다시 볼 단어"를 정한다. 기기에만 둔다(복습 기록은 계정 간 옮길 필요가
/// 작고, 서버에 매번 쓰지 않으려고). 간격은 1·3·7·14·30일, "다시"면 처음부터.
class WordReviewStore {
  WordReviewStore._();

  static const intervals = [1, 3, 7, 14, 30];

  static String _key(String accountId) =>
      'parrokit.word_reviews.v1.$accountId';

  static Future<Map<String, WordReview>> loadAll(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(accountId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: _fromJson(entry.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  static WordReview _fromJson(Map json) {
    DateTime? time(String key) => json[key] is int
        ? DateTime.fromMillisecondsSinceEpoch(json[key] as int)
        : null;
    return WordReview(
      step: json['step'] is int ? json['step'] as int : 0,
      dueAt: time('dueAt'),
      lastReviewedAt: time('lastReviewedAt'),
    );
  }

  /// [now] 기준으로 복습할 단어. 기한이 지난 것부터, 새 단어는 뒤에.
  static List<MyWord> dueWords(
    List<MyWord> words,
    Map<String, WordReview> reviews,
    DateTime now,
  ) {
    bool isDue(MyWord w) {
      final due = reviews[w.id]?.dueAt;
      return due == null || !due.isAfter(now);
    }

    final due = words.where(isDue).toList();
    due.sort((a, b) {
      final da = reviews[a.id]?.dueAt, db = reviews[b.id]?.dueAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return due;
  }

  /// 복습 결과를 남긴다. [known]이면 다음 간격 뒤로, 아니면 처음부터(오늘 다시).
  static Future<WordReview> record(
    String accountId,
    String wordId, {
    required bool known,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final all = await loadAll(accountId);
    final current = all[wordId] ?? const WordReview();
    final next = known
        ? WordReview(
            step: current.step + 1,
            dueAt: at.add(Duration(
                days: intervals[current.step.clamp(0, intervals.length - 1)])),
            lastReviewedAt: at,
          )
        : WordReview(step: 0, dueAt: at, lastReviewedAt: at);
    all[wordId] = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(accountId),
      jsonEncode({
        for (final e in all.entries)
          e.key: {
            'step': e.value.step,
            if (e.value.dueAt != null)
              'dueAt': e.value.dueAt!.millisecondsSinceEpoch,
            if (e.value.lastReviewedAt != null)
              'lastReviewedAt': e.value.lastReviewedAt!.millisecondsSinceEpoch,
          },
      }),
    );
    MyWordStore.revision.value++;
    return next;
  }
}
