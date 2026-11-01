import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 따라 말하기 한 번의 시도 기록.
class PracticeAttempt {
  const PracticeAttempt({
    required this.at,
    required this.sentenceId,
    required this.success,
    required this.durationMs,
    this.score,
    this.heard = '',
    this.manual = false,
  });

  final DateTime at;
  final String sentenceId;

  /// 인식 일치율(0~1). 체크 버튼으로 직접 넘긴 경우 null.
  final double? score;

  /// 인식된 원문. 기준을 바꿔도 다시 계산할 수 있게 함께 남긴다.
  final String heard;
  final bool success;

  /// 음성 인식 없이 체크 버튼으로 완료한 시도.
  final bool manual;

  /// 마이크를 켠 채 연습한 시간.
  final int durationMs;

  Map<String, Object> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'sentenceId': sentenceId,
        if (score != null) 'score': score!,
        if (heard.isNotEmpty) 'heard': heard,
        'success': success,
        if (manual) 'manual': true,
        'durationMs': durationMs,
      };

  static PracticeAttempt? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final at = value['at'];
    final sentenceId = value['sentenceId'];
    if (at is! num || sentenceId is! String) return null;
    return PracticeAttempt(
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      sentenceId: sentenceId,
      score: (value['score'] as num?)?.toDouble().clamp(0.0, 1.0),
      heard: value['heard'] as String? ?? '',
      success: value['success'] as bool? ?? false,
      manual: value['manual'] as bool? ?? false,
      durationMs: (value['durationMs'] as num?)?.toInt().clamp(0, 1 << 31) ?? 0,
    );
  }
}

/// 시도 기록을 계정별로 쌓는다. 횟수, 숙련도, 연속 학습일은 이 기록에서 계산할 수 있다.
class PracticeLogStore {
  PracticeLogStore._();

  /// 오래된 기록은 잘라 저장 용량을 막는다.
  static const maxEntries = 2000;
  static const maxAge = Duration(days: 180);

  /// 시도가 쌓일 때마다 오른다. 기록 화면이 실시간으로 갱신하는 데 쓴다.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String _key(String accountId) => 'parrokit.practice_log.v1.$accountId';

  static Future<List<PracticeAttempt>> load(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(accountId));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (PracticeAttempt.fromJson(item) case final attempt?) attempt,
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(String accountId, PracticeAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await load(accountId);
    all.add(attempt);
    final cutoff = DateTime.now().subtract(maxAge);
    final kept = all.where((a) => a.at.isAfter(cutoff)).toList();
    final trimmed = kept.length > maxEntries
        ? kept.sublist(kept.length - maxEntries)
        : kept;
    await prefs.setString(
      _key(accountId),
      jsonEncode([for (final a in trimmed) a.toJson()]),
    );
    debugPrint('[practice] ${attempt.sentenceId} '
        'score=${attempt.score?.toStringAsFixed(2) ?? '-'} '
        'success=${attempt.success} manual=${attempt.manual} '
        'duration=${attempt.durationMs}ms heard="${attempt.heard}"');
    revision.value++;
  }
}

/// 시도 기록의 합계. 음성 인식으로 한 시도만 성공률에 넣고, 직접 넘긴 건 따로 센다.
class PracticeLogSummary {
  const PracticeLogSummary({
    required this.attempts,
    required this.successes,
    required this.manualCount,
    required this.totalDuration,
    required this.bestScores,
    required this.lastScores,
  });

  /// 음성 인식으로 한 시도 수와 그중 성공 수.
  final int attempts;
  final int successes;
  final int manualCount;
  final Duration totalDuration;
  final Map<String, double> bestScores;
  final Map<String, double> lastScores;

  double? get successRate => attempts == 0 ? null : successes / attempts;
  bool get isEmpty => attempts == 0 && manualCount == 0;

  factory PracticeLogSummary.build(
    List<PracticeAttempt> log, {
    Set<String>? sentenceIds,
  }) {
    final sorted = log
        .where((a) => sentenceIds == null || sentenceIds.contains(a.sentenceId))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    var attempts = 0;
    var successes = 0;
    var manual = 0;
    var durationMs = 0;
    final best = <String, double>{};
    final last = <String, double>{};
    for (final a in sorted) {
      durationMs += a.durationMs;
      if (a.manual) {
        manual++;
        continue;
      }
      attempts++;
      if (a.success) successes++;
      final score = a.score;
      if (score != null) {
        last[a.sentenceId] = score;
        if (score > (best[a.sentenceId] ?? -1)) best[a.sentenceId] = score;
      }
    }
    return PracticeLogSummary(
      attempts: attempts,
      successes: successes,
      manualCount: manual,
      totalDuration: Duration(milliseconds: durationMs),
      bestScores: best,
      lastScores: last,
    );
  }
}
