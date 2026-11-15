import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'my_word_store.dart';

/// 복습하고 고르는 답. SM-2의 네 칸 중 '어려움'은 빼고 셋만 쓴다.
enum ReviewRating {
  /// 못 떠올렸다. 오늘 다시 보고, 쉬움 계수를 내린다.
  again,

  /// 떠올렸다. 보통 간격으로 민다.
  known,

  /// 바로 떠올랐다. 더 멀리 민다.
  easy,
}

/// 단어 하나의 복습 상태.
class WordReview {
  const WordReview({
    this.step = 0,
    this.dueAt,
    this.lastReviewedAt,
    this.ease,
    this.intervalDays,
  });

  /// 몇 번 연달아 맞췄는지. 0이면 새 단어거나 "다시"를 누른 단어.
  /// 화면의 복습 단계 점이 이 값을 쓴다.
  final int step;

  /// 이 시각이 지나면 오늘 다시 볼 단어다. 없으면 바로 볼 단어(새 단어).
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;

  /// 이 단어가 얼마나 쉬운지(SM-2의 ease factor). 클수록 간격이 빨리 벌어진다.
  /// 예전 기록에는 없어서 null이면 [WordReviewStore.defaultEase]로 본다(5차).
  final double? ease;

  /// 지금 간격(일). 예전 기록에는 없어서 null이면 [step]으로 환산한다.
  final int? intervalDays;

  double get easeOrDefault => ease ?? WordReviewStore.defaultEase;

  /// 지금 간격. 예전 기록(step만 있는 것)도 쓰던 간격 그대로 이어받는다.
  int get intervalOrFromStep =>
      intervalDays ?? WordReviewStore.intervalForStep(step);
}

/// "오늘 다시 볼 단어"를 정한다. 기기에만 둔다(복습 기록은 계정 간 옮길 필요가
/// 작고, 서버에 매번 쓰지 않으려고).
///
/// 간격은 SM-2로 정한다(5차, 사용자 요청). 전에는 1·3·7·14·30일 고정이라
/// 쉬운 단어도 30일에서 멈췄고, 자꾸 틀리는 단어도 남들과 같은 속도로 벌어졌다.
/// 이제 단어마다 '쉬움 계수(ease)'를 들고 다니며 간격을 곱해 간다.
class WordReviewStore {
  WordReviewStore._();

  /// 예전 기록을 읽을 때와 화면의 복습 단계 점에 쓰는 간격 표.
  static const intervals = [1, 3, 7, 14, 30];

  /// SM-2 기본 쉬움 계수. 맞출 때마다 간격이 대략 이 배로 늘어난다.
  static const double defaultEase = 2.5;

  /// 계수가 이보다 내려가지는 않는다(SM-2와 같다). 너무 자주 나오는 것을 막는다.
  static const double minEase = 1.3;

  /// 처음 맞췄을 때와 두 번째 맞췄을 때의 간격(일). 그 뒤부터 곱해 간다.
  static const int firstInterval = 1;
  static const int secondInterval = 3;

  /// 간격이 아무리 벌어져도 이 날을 넘지 않는다. 1년쯤에서 멈춘다.
  static const int maxInterval = 365;

  /// 예전 기록(step만 있는 것)이 쓰던 간격.
  static int intervalForStep(int step) =>
      step <= 0 ? 0 : intervals[(step - 1).clamp(0, intervals.length - 1)];

  /// 답에 따라 바뀐 쉬움 계수. SM-2의 식을 셋으로 줄여 쓴다.
  static double nextEase(double ease, ReviewRating rating) {
    final next = switch (rating) {
      ReviewRating.again => ease - 0.2,
      ReviewRating.known => ease,
      ReviewRating.easy => ease + 0.15,
    };
    return next.clamp(minEase, 3.5);
  }

  /// 답에 따라 바뀐 간격(일). '다시'는 0(오늘 다시 본다).
  static int nextInterval({
    required int interval,
    required int step,
    required double ease,
    required ReviewRating rating,
  }) {
    if (rating == ReviewRating.again) return 0;
    final base = switch (step) {
      0 => firstInterval,
      1 => secondInterval,
      _ => (interval * ease).round(),
    };
    // 바로 떠오른 단어는 한 번 더 밀어 준다(SM-2의 easy bonus).
    final withBonus =
        rating == ReviewRating.easy ? (base * 1.3).round() : base;
    return withBonus.clamp(1, maxInterval);
  }

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
      ease: (json['ease'] as num?)?.toDouble(),
      intervalDays: (json['intervalDays'] as num?)?.toInt(),
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

  /// [at]에서 [days]일 뒤 그날 0시(기기 시간). 예전엔 정확히 n일 뒤 같은
  /// 시각이라, 밤 11시에 '알아요'를 누른 단어는 다음 날 밤 11시가 돼야 다시
  /// 나왔다(5차). 단어 앱처럼 그날이 되면 아침부터 나온다.
  static DateTime dueDayAfter(DateTime at, int days) =>
      DateTime(at.year, at.month, at.day + days);

  /// 복습 결과를 남긴다. 간격과 쉬움 계수를 함께 갱신한다.
  static Future<WordReview> record(
    String accountId,
    String wordId, {
    required ReviewRating rating,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final all = await loadAll(accountId);
    final current = all[wordId] ?? const WordReview();
    final ease = nextEase(current.easeOrDefault, rating);
    final interval = nextInterval(
      interval: current.intervalOrFromStep,
      step: current.step,
      ease: ease,
      rating: rating,
    );
    final next = WordReview(
      // '다시'면 단계가 처음으로 돌아간다. 화면의 점도 비워진다.
      step: rating == ReviewRating.again ? 0 : current.step + 1,
      dueAt: rating == ReviewRating.again ? at : dueDayAfter(at, interval),
      lastReviewedAt: at,
      ease: ease,
      intervalDays: interval,
    );
    all[wordId] = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(accountId),
      jsonEncode({
        for (final e in all.entries)
          e.key: {
            'step': e.value.step,
            if (e.value.ease != null) 'ease': e.value.ease,
            if (e.value.intervalDays != null)
              'intervalDays': e.value.intervalDays,
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
