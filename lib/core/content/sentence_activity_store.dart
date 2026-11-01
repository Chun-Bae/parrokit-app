import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SentenceActivity {
  const SentenceActivity({
    this.parrotSpeakCount = 0,
    this.practiceCount = 0,
    this.listenCount = 0,
    this.lastPracticedAt,
    this.routineEnabled = true,
    this.liked = false,
  });

  final int parrotSpeakCount;
  final int practiceCount;

  /// 듣기 모드에서 앵무새 음성을 끝까지 들은 횟수.
  final int listenCount;

  /// 따라 말하기를 마지막으로 완료한 시각. 한 번도 안 했으면 null.
  final DateTime? lastPracticedAt;
  final bool routineEnabled;

  /// 이 문장에 좋아요를 눌렀는지. 서버가 없어서 이 기기에만 저장한다.
  final bool liked;

  SentenceActivity copyWith({
    int? parrotSpeakCount,
    int? practiceCount,
    int? listenCount,
    DateTime? lastPracticedAt,
    bool? routineEnabled,
    bool? liked,
  }) =>
      SentenceActivity(
        parrotSpeakCount: parrotSpeakCount ?? this.parrotSpeakCount,
        practiceCount: practiceCount ?? this.practiceCount,
        listenCount: listenCount ?? this.listenCount,
        lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
        routineEnabled: routineEnabled ?? this.routineEnabled,
        liked: liked ?? this.liked,
      );

  Map<String, Object> toJson() => {
        if (lastPracticedAt != null)
          'lastPracticedAt': lastPracticedAt!.millisecondsSinceEpoch,
        'parrotSpeakCount': parrotSpeakCount,
        'practiceCount': practiceCount,
        'listenCount': listenCount,
        'routineEnabled': routineEnabled,
        if (liked) 'liked': true,
      };

  factory SentenceActivity.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const SentenceActivity();
    return SentenceActivity(
      parrotSpeakCount:
          (value['parrotSpeakCount'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      practiceCount:
          (value['practiceCount'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      listenCount:
          (value['listenCount'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      lastPracticedAt: switch (value['lastPracticedAt']) {
        final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        _ => null,
      },
      routineEnabled: value['routineEnabled'] as bool? ?? true,
      liked: value['liked'] as bool? ?? false,
    );
  }
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

  static Future<void> incrementPractice(
    String accountId,
    String sentenceId,
  ) =>
      _update(
        accountId,
        sentenceId,
        (activity) => activity.copyWith(
          practiceCount: activity.practiceCount + 1,
          lastPracticedAt: DateTime.now(),
        ),
      );

  static Future<void> incrementListen(
    String accountId,
    String sentenceId,
  ) =>
      _update(
        accountId,
        sentenceId,
        (activity) => activity.copyWith(
          listenCount: activity.listenCount + 1,
        ),
      );

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
