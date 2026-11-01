import 'package:flutter/material.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/practice_log.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_history.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';

/// 캐릭터 아래에서 내가 연습한 문장의 기록을 한눈에 보여주는 대시보드.
class SentenceHistoryDashboard extends StatefulWidget {
  const SentenceHistoryDashboard({
    super.key,
    required this.accountId,
    required this.language,
    this.refreshToken = 0,
    this.onViewAll,
  });

  final String accountId;
  final String language;

  /// 값이 바뀌면 기록을 다시 읽는다. 연습을 마칠 때마다 올려준다.
  final int refreshToken;
  final VoidCallback? onViewAll;

  @override
  State<SentenceHistoryDashboard> createState() =>
      _SentenceHistoryDashboardState();
}

class _SentenceHistoryDashboardState extends State<SentenceHistoryDashboard> {
  SentenceHistorySummary? summary;
  PracticeLogSummary? practice;

  @override
  void initState() {
    super.initState();
    SentenceActivityStore.activityRevision.addListener(load);
    PracticeLogStore.revision.addListener(load);
    load();
  }

  @override
  void dispose() {
    SentenceActivityStore.activityRevision.removeListener(load);
    PracticeLogStore.revision.removeListener(load);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SentenceHistoryDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.language != widget.language ||
        oldWidget.refreshToken != widget.refreshToken) {
      load();
    }
  }

  Future<void> load() async {
    final accountId = widget.accountId;
    final language = widget.language;
    try {
      final mine = await MySentenceStore.loadFor(accountId, language);
      final activities = await SentenceActivityStore.loadAll(accountId);
      final log = await PracticeLogStore.load(accountId);
      if (!mounted ||
          accountId != widget.accountId ||
          language != widget.language) {
        return;
      }
      final sentences = [...defaultSentencesFor(language), ...mine];
      setState(() {
        summary = SentenceHistorySummary.build(sentences, activities);
        practice = PracticeLogSummary.build(
          log,
          sentenceIds: {for (final sentence in sentences) sentence.id},
        );
      });
    } catch (_) {
      // 기록을 못 읽으면 빈 상태로 보여준다.
      if (mounted) {
        setState(
            () => summary = SentenceHistorySummary.build(const [], const {}));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF24364F);
    const muted = Color(0xFF61758D);
    final data = summary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF46637A).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('내 문장 기록',
                  style: TextStyle(
                      color: ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4))),
          if (widget.onViewAll != null)
            TextButton(
                onPressed: widget.onViewAll,
                child: const Text('전체 보기', style: TextStyle(color: muted))),
        ]),
        const SizedBox(height: 12),
        if (data == null)
          const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator()))
        else if (data.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('아직 연습한 문장이 없어요. 앵무새를 따라 말하면 여기에 기록돼요.',
                  style: TextStyle(color: muted, fontSize: 13, height: 1.5)))
        else ...[
          _Stats(data: data),
          if (practice case final log? when !log.isEmpty) ...[
            const SizedBox(height: 10),
            _AttemptLine(log: log),
          ],
          const SizedBox(height: 18),
          _MasteryBar(data: data),
          if (data.recent.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('최근 연습한 문장'),
            for (final item in data.recent)
              _HistoryRow(
                  item: item,
                  bestScore: practice?.bestScores[item.sentence.id]),
          ],
          if (data.needsWork.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionTitle('따라 말해보면 좋은 문장'),
            for (final item in data.needsWork)
              _HistoryRow(item: item, showListen: true),
          ],
        ],
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF61758D),
              fontSize: 12,
              fontWeight: FontWeight.w800)));
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data});
  final SentenceHistorySummary data;

  @override
  Widget build(BuildContext context) => Row(children: [
        _Stat(label: '익힌 문장', value: '${data.practicedCount}'),
        _Stat(label: '따라 말하기', value: '${data.totalPractice}회'),
        _Stat(label: '들은 횟수', value: '${data.totalListen}회'),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: Color(0xFF24364F),
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Color(0xFF61758D), fontSize: 11)),
      ]));
}

Color masteryColor(SentenceMastery mastery) => switch (mastery) {
      SentenceMastery.fresh => const Color(0xFFD9E3EA),
      SentenceMastery.learning => const Color(0xFFA8CBE8),
      SentenceMastery.familiar => const Color(0xFF6D9890),
    };

class _MasteryBar extends StatelessWidget {
  const _MasteryBar({required this.data});
  final SentenceHistorySummary data;

  @override
  Widget build(BuildContext context) {
    final total =
        data.masteryCounts.values.fold<int>(0, (sum, count) => sum + count);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
              height: 10,
              child: Row(children: [
                for (final mastery in SentenceMastery.values.reversed)
                  if ((data.masteryCounts[mastery] ?? 0) > 0)
                    Expanded(
                        flex: data.masteryCounts[mastery]!,
                        child: ColoredBox(color: masteryColor(mastery))),
              ]))),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (final mastery in SentenceMastery.values.reversed)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: masteryColor(mastery), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${mastery.label} ${data.masteryCounts[mastery] ?? 0}',
                style: const TextStyle(color: Color(0xFF61758D), fontSize: 11)),
          ]),
        if (total == 0) const SizedBox.shrink(),
      ]),
    ]);
  }
}

/// 시도 횟수, 성공률, 연습 시간을 한 줄로 보여준다.
class _AttemptLine extends StatelessWidget {
  const _AttemptLine({required this.log});
  final PracticeLogSummary log;

  @override
  Widget build(BuildContext context) {
    final rate = log.successRate;
    final minutes = log.totalDuration.inMinutes;
    final seconds = log.totalDuration.inSeconds % 60;
    final parts = [
      '시도 ${log.attempts}회',
      if (rate != null) '성공률 ${(rate * 100).round()}%',
      '연습 ${minutes > 0 ? '$minutes분 ' : ''}$seconds초',
      if (log.manualCount > 0) '직접 완료 ${log.manualCount}회',
    ];
    return Center(
        child: Text(parts.join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF61758D), fontSize: 11)));
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow(
      {required this.item, this.showListen = false, this.bestScore});
  final SentenceHistoryItem item;
  final bool showListen;

  /// 이 문장의 최고 인식 일치율(0~1). 기록이 없으면 null.
  final double? bestScore;

  @override
  Widget build(BuildContext context) {
    final last = item.activity.lastPracticedAt;
    final detail = showListen
        ? '들은 ${item.activity.listenCount}회 · 따라 말하기 ${item.activity.practiceCount}회'
        : '${last == null ? '' : '${relativeDayLabel(DateTime.now(), last)} · '}'
            '따라 말하기 ${item.activity.practiceCount}회'
            '${bestScore == null ? '' : ' · 최고 ${(bestScore! * 100).round()}%'}';
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                  color: masteryColor(item.mastery),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.sentence.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF24364F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(
                        color: Color(0xFF61758D), fontSize: 11)),
              ])),
          Text(item.mastery.label,
              style: TextStyle(
                  color: masteryColor(item.mastery) == const Color(0xFFD9E3EA)
                      ? const Color(0xFF61758D)
                      : masteryColor(item.mastery),
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ]));
  }
}
