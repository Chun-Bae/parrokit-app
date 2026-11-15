import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SentenceActivity {
  const SentenceActivity({
    this.parrotSpeakCount = 0,
    this.practiceCount = 0,
    this.practicePoints,
    this.listenCount = 0,
    this.lastPracticedAt,
    this.routineEnabled = true,
    this.liked = false,
    this.memo = '',
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
  final int listenCount;

  /// 따라 말하기를 마지막으로 완료한 시각. 한 번도 안 했으면 null.
  final DateTime? lastPracticedAt;
  final bool routineEnabled;

  /// 이 문장에 좋아요를 눌렀는지. 서버가 없어서 이 기기에만 저장한다.
  final bool liked;

  /// 이 문장에 대한 내 메모. 이 기기에만 저장한다.
  final String memo;

  SentenceActivity copyWith({
    int? parrotSpeakCount,
    int? practiceCount,
    int? practicePoints,
    int? listenCount,
    DateTime? lastPracticedAt,
    bool? routineEnabled,
    bool? liked,
    String? memo,
  }) =>
      SentenceActivity(
        parrotSpeakCount: parrotSpeakCount ?? this.parrotSpeakCount,
        practiceCount: practiceCount ?? this.practiceCount,
        practicePoints: practicePoints ?? this.practicePoints,
        listenCount: listenCount ?? this.listenCount,
        lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
        routineEnabled: routineEnabled ?? this.routineEnabled,
        liked: liked ?? this.liked,
        memo: memo ?? this.memo,
      );

  Map<String, Object> toJson() => {
        if (lastPracticedAt != null)
          'lastPracticedAt': lastPracticedAt!.millisecondsSinceEpoch,
        'parrotSpeakCount': parrotSpeakCount,
        'practiceCount': practiceCount,
        if (practicePoints != null) 'practicePoints': practicePoints!,
        'listenCount': listenCount,
        'routineEnabled': routineEnabled,
        if (liked) 'liked': true,
        if (memo.isNotEmpty) 'memo': memo,
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
      lastPracticedAt: switch (value['lastPracticedAt']) {
        final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        _ => null,
      },
      routineEnabled: value['routineEnabled'] as bool? ?? true,
      liked: value['liked'] as bool? ?? false,
      memo: value['memo'] as String? ?? '',
    );
  }
}

/// 따라 말하기 한 번이 숙련도에 더하는 점수. 100점이면 2점, 50점이면 1점.
/// 점수를 모르면 1점(예전 기본값의 절반).
int practiceGain(double? score) {
  if (score == null) return 1;
  return (score.clamp(0.0, 1.0) * 2).round();
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

  /// 따라 말하기 한 번을 기록한다. [score](0~1)가 높을수록 숙련도가 많이 오른다.
  ///
  /// 점수를 모르면(체크로 그냥 넘긴 경우) 1점만 준다. 전에는 점수와 상관없이
  /// 늘 2점이었다(5차, 사용자 요청).
  static Future<void> incrementPractice(
    String accountId,
    String sentenceId, {
    double? score,
  }) =>
      _update(
        accountId,
        sentenceId,
        (activity) => activity.copyWith(
          practiceCount: activity.practiceCount + 1,
          practicePoints: activity.practiceScore + practiceGain(score),
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
