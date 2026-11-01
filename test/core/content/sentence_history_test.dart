import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_history.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';

DefaultConversationSentence sentence(String id) => DefaultConversationSentence(
    id: id,
    language: '영어',
    text: id,
    translation: '',
    pronunciation: '',
    topic: '');

void main() {
  final sentences = [
    for (final id in ['a', 'b', 'c', 'd']) sentence(id)
  ];

  test('기록이 없으면 빈 상태이고 모두 새 문장이다', () {
    final summary = SentenceHistorySummary.build(sentences, const {});
    expect(summary.isEmpty, isTrue);
    expect(summary.masteryCounts[SentenceMastery.fresh], 4);
    expect(summary.recent, isEmpty);
  });

  test('합계, 숙련도 분포, 최근 순서를 계산한다', () {
    final summary = SentenceHistorySummary.build(sentences, {
      'a': SentenceActivity(
          practiceCount: 5, lastPracticedAt: DateTime(2026, 1, 1)),
      'b': SentenceActivity(
          practiceCount: 1,
          listenCount: 2,
          lastPracticedAt: DateTime(2026, 1, 3)),
    });
    expect(summary.practicedCount, 2);
    expect(summary.totalPractice, 6);
    expect(summary.totalListen, 2);
    expect(summary.masteryCounts[SentenceMastery.familiar], 1);
    expect(summary.masteryCounts[SentenceMastery.learning], 1);
    expect(summary.masteryCounts[SentenceMastery.fresh], 2);
    expect(summary.recent.map((i) => i.sentence.id), ['b', 'a']);
  });

  test('많이 듣고 따라 말하기가 적은 문장을 추천한다', () {
    final summary = SentenceHistorySummary.build(sentences, {
      'a': const SentenceActivity(listenCount: 9, practiceCount: 1),
      'b': const SentenceActivity(listenCount: 9, practiceCount: 5),
      'c': const SentenceActivity(listenCount: 2),
    });
    expect(summary.needsWork.map((i) => i.sentence.id), ['a']);
  });
}
