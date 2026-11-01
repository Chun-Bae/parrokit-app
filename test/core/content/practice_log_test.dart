import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/practice_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

PracticeAttempt attempt(
  String id, {
  DateTime? at,
  double? score,
  bool success = false,
  bool manual = false,
  int durationMs = 1000,
}) =>
    PracticeAttempt(
      at: at ?? DateTime.now(),
      sentenceId: id,
      score: score,
      success: success,
      manual: manual,
      durationMs: durationMs,
      heard: 'x',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('시도를 저장하고 다시 읽는다', () async {
    final before = PracticeLogStore.revision.value;
    await PracticeLogStore.add('u', attempt('a', score: 0.9, success: true));
    final log = await PracticeLogStore.load('u');
    expect(log, hasLength(1));
    expect(log.single.sentenceId, 'a');
    expect(log.single.score, 0.9);
    expect(log.single.success, isTrue);
    expect(log.single.heard, 'x');
    expect(PracticeLogStore.revision.value, before + 1);
  });

  test('오래된 기록은 버리고 최대 개수를 넘으면 앞에서 자른다', () async {
    await PracticeLogStore.add('u',
        attempt('old', at: DateTime.now().subtract(const Duration(days: 200))));
    await PracticeLogStore.add('u', attempt('new'));
    expect(
        (await PracticeLogStore.load('u')).map((a) => a.sentenceId), ['new']);
  });

  test('성공률, 최고·최근 점수, 연습 시간을 계산한다', () {
    final t = DateTime(2026, 1, 1);
    final summary = PracticeLogSummary.build([
      attempt('a', at: t, score: 0.5, durationMs: 2000),
      attempt('a',
          at: t.add(const Duration(minutes: 1)),
          score: 0.9,
          success: true,
          durationMs: 3000),
      attempt('a', at: t.add(const Duration(minutes: 2)), score: 0.6),
      attempt('b', at: t, success: true, manual: true, durationMs: 0),
    ]);
    expect(summary.attempts, 3);
    expect(summary.successes, 1);
    expect(summary.manualCount, 1);
    expect(summary.successRate, closeTo(1 / 3, 0.001));
    expect(summary.bestScores['a'], 0.9);
    expect(summary.lastScores['a'], 0.6);
    expect(summary.totalDuration, const Duration(seconds: 6));
  });

  test('문장 id로 걸러서 계산한다', () {
    final summary = PracticeLogSummary.build(
      [
        attempt('a', score: 1, success: true),
        attempt('b', score: 1, success: true)
      ],
      sentenceIds: {'a'},
    );
    expect(summary.attempts, 1);
  });

  test('손상된 기록은 건너뛴다', () {
    expect(PracticeAttempt.fromJson({'at': 'bad'}), isNull);
    expect(PracticeAttempt.fromJson(null), isNull);
  });
}
