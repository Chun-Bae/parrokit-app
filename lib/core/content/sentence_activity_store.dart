import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SentenceActivity {
  const SentenceActivity({
    this.parrotSpeakCount = 0,
    this.practiceCount = 0,
    this.routineEnabled = true,
  });

  final int parrotSpeakCount;
  final int practiceCount;
  final bool routineEnabled;

  SentenceActivity copyWith({
    int? parrotSpeakCount,
    int? practiceCount,
    bool? routineEnabled,
  }) =>
      SentenceActivity(
        parrotSpeakCount: parrotSpeakCount ?? this.parrotSpeakCount,
        practiceCount: practiceCount ?? this.practiceCount,
        routineEnabled: routineEnabled ?? this.routineEnabled,
      );

  Map<String, Object> toJson() => {
        'parrotSpeakCount': parrotSpeakCount,
        'practiceCount': practiceCount,
        'routineEnabled': routineEnabled,
      };

  factory SentenceActivity.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const SentenceActivity();
    return SentenceActivity(
      parrotSpeakCount:
          (value['parrotSpeakCount'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      practiceCount:
          (value['practiceCount'] as num?)?.clamp(0, 1 << 31).toInt() ?? 0,
      routineEnabled: value['routineEnabled'] as bool? ?? true,
    );
  }
}

class SentenceActivityStore {
  SentenceActivityStore._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

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
    if (notifyRoutine) revision.value++;
  }
}
