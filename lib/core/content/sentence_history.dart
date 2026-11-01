import 'default_conversation_sentences.dart';
import 'sentence_activity_store.dart';
import 'sentence_mastery.dart';

class SentenceHistoryItem {
  const SentenceHistoryItem({
    required this.sentence,
    required this.activity,
    required this.mastery,
  });

  final DefaultConversationSentence sentence;
  final SentenceActivity activity;
  final SentenceMastery mastery;
}

/// 홈 대시보드용 문장 기록 요약. 저장된 활동 기록에서 계산하며 따로 저장하지 않는다.
class SentenceHistorySummary {
  const SentenceHistorySummary({
    required this.practicedCount,
    required this.totalPractice,
    required this.totalListen,
    required this.masteryCounts,
    required this.recent,
    required this.needsWork,
  });

  /// 한 번이라도 연습하거나 들은 문장 수.
  final int practicedCount;
  final int totalPractice;
  final int totalListen;
  final Map<SentenceMastery, int> masteryCounts;

  /// 최근에 따라 말한 문장, 최신순.
  final List<SentenceHistoryItem> recent;

  /// 많이 들었지만 따라 말하기는 적은 문장. 다음에 연습하면 좋은 후보.
  final List<SentenceHistoryItem> needsWork;

  bool get isEmpty => practicedCount == 0;

  factory SentenceHistorySummary.build(
    List<DefaultConversationSentence> sentences,
    Map<String, SentenceActivity> activities, {
    int recentLimit = 5,
    int needsWorkLimit = 3,
  }) {
    final items = [
      for (final sentence in sentences)
        SentenceHistoryItem(
          sentence: sentence,
          activity: activities[sentence.id] ?? const SentenceActivity(),
          mastery:
              masteryOf(activities[sentence.id] ?? const SentenceActivity()),
        ),
    ];
    final counts = {for (final m in SentenceMastery.values) m: 0};
    var practiced = 0;
    var totalPractice = 0;
    var totalListen = 0;
    for (final item in items) {
      counts[item.mastery] = counts[item.mastery]! + 1;
      totalPractice += item.activity.practiceCount;
      totalListen += item.activity.listenCount;
      if (item.mastery != SentenceMastery.fresh) practiced++;
    }
    final recent = items
        .where((item) => item.activity.lastPracticedAt != null)
        .toList()
      ..sort((a, b) =>
          b.activity.lastPracticedAt!.compareTo(a.activity.lastPracticedAt!));
    final needsWork = items
        .where((item) =>
            item.activity.listenCount >= 3 &&
            item.activity.practiceCount < item.activity.listenCount ~/ 3)
        .toList()
      ..sort(
          (a, b) => b.activity.listenCount.compareTo(a.activity.listenCount));
    return SentenceHistorySummary(
      practicedCount: practiced,
      totalPractice: totalPractice,
      totalListen: totalListen,
      masteryCounts: counts,
      recent: recent.take(recentLimit).toList(growable: false),
      needsWork: needsWork.take(needsWorkLimit).toList(growable: false),
    );
  }
}
