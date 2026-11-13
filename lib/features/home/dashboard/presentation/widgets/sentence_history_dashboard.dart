import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/practice_log.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_history.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 캐릭터 아래에서 내가 연습한 문장의 기록을 한눈에 보여주는 대시보드.
class SentenceHistoryDashboard extends StatefulWidget {
  const SentenceHistoryDashboard({
    super.key,
    required this.accountId,
    required this.language,
    this.refreshToken = 0,
    this.onViewAll,
    this.compact = false,
  });

  /// 새 디자인 홈. 숫자 3개, 친밀도 막대, 최근 문장 3개만 보여주고 시도·성공률
  /// 줄과 "따라 말해보면 좋은 문장"은 뺀다. 전에는 한 카드에 일곱 덩어리가
  /// 있어서 홈이 길어졌다. 나머지는 "전체 보기"에서 본다.
  final bool compact;

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
    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;
    final data = summary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        // 새 디자인은 그림자 없이 바탕색만으로 나눈다.
        boxShadow: widget.compact
            ? null
            : [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('내 문장 기록',
                  style: context.texts.headlineSmall
                      .copyWith(color: ink, letterSpacing: -0.4))),
          if (widget.onViewAll != null)
            TextButton(
                onPressed: widget.onViewAll,
                child: Text('전체 보기', style: TextStyle(color: muted))),
        ]),
        const SizedBox(height: 12),
        if (data == null)
          const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator()))
        else if (data.isEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('아직 연습한 문장이 없어요. 앵무새를 따라 말하면 여기에 기록돼요.',
                  style: context.texts.labelMedium
                      .copyWith(color: muted, height: 1.5)))
        else ...[
          _Stats(data: data),
          if (practice case final log? when !log.isEmpty && !widget.compact) ...[
            const SizedBox(height: 10),
            _AttemptLine(log: log),
          ],
          const SizedBox(height: 18),
          _MasteryBar(data: data),
          if (data.recent.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('최근 연습한 문장'),
            for (final item
                in widget.compact ? data.recent.take(3) : data.recent)
              _HistoryRow(
                  item: item,
                  bestScore: practice?.bestScores[item.sentence.id]),
          ],
          if (data.needsWork.isNotEmpty && !widget.compact) ...[
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
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: context.texts.bodySmall.copyWith(color: palette.muted)));
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data});
  final SentenceHistorySummary data;

  @override
  Widget build(BuildContext context) => Row(children: [
        // 한 번이라도 연습하거나 들은 문장 수. 예전 '익힌 문장'은 바로 아래 '익숙함 0'과
        // 어긋나 보였다(5차).
        _Stat(label: '연습한 문장', value: '${data.practicedCount}'),
        _Stat(label: '따라 말하기', value: '${data.totalPractice}회'),
        // '따라 말하기'와 짝을 맞춘다(예전 '들은 횟수', 5차).
        _Stat(label: '듣기', value: '${data.totalListen}회'),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    return Expanded(
        child: Column(children: [
      Text(value,
          style: context.texts.headlineSmall.copyWith(color: palette.ink)),
      const SizedBox(height: 2),
      Text(label,
          style: context.texts.labelSmall.copyWith(color: palette.muted)),
    ]));
  }
}

/// 친밀도 단계 글자색. 막대·점에 쓰는 [masteryColor]는 옅어서, 흰 카드 위
/// 글자로 쓰면 "익히는 중"(A8CBE8)의 대비가 약 1.7:1밖에 안 됐다. 같은
/// 계열에서 글자로 읽히는 진한 색을 쓴다.
Color masteryTextColor(BuildContext context, SentenceMastery mastery) {
  final palette = HomeTokens.of(context);
  return switch (mastery) {
    SentenceMastery.fresh => palette.muted,
    SentenceMastery.learning => palette.primary,
    SentenceMastery.familiar => palette.good,
  };
}

Color masteryColor(BuildContext context, SentenceMastery mastery) {
  final palette = HomeTokens.of(context);
  return switch (mastery) {
    SentenceMastery.fresh => palette.mastery[0],
    SentenceMastery.learning => palette.mastery[1],
    SentenceMastery.familiar => palette.mastery[2],
  };
}

class _MasteryBar extends StatelessWidget {
  const _MasteryBar({required this.data});
  final SentenceHistorySummary data;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
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
                        child:
                            ColoredBox(color: masteryColor(context, mastery))),
              ]))),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (final mastery in SentenceMastery.values.reversed)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: masteryColor(context, mastery),
                    shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${mastery.label} ${data.masteryCounts[mastery] ?? 0}',
                style: context.texts.labelSmall.copyWith(color: palette.muted)),
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
    final palette = HomeTokens.of(context);
    final parts = [
      '시도 ${log.attempts}회',
      if (rate != null) '성공률 ${(rate * 100).round()}%',
      '연습 ${minutes > 0 ? '$minutes분 ' : ''}$seconds초',
      if (log.manualCount > 0) '직접 완료 ${log.manualCount}회',
    ];
    return Center(
        child: Text(parts.join(' · '),
            textAlign: TextAlign.center,
            style: context.texts.labelSmall.copyWith(color: palette.muted)));
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
    final palette = HomeTokens.of(context);
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
                  color: masteryColor(context, item.mastery),
                  borderRadius: BorderRadius.circular(AppRadius.track))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.sentence.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        context.texts.bodyMedium.copyWith(color: palette.ink)),
                const SizedBox(height: 2),
                Text(detail,
                    style: context.texts.labelSmall
                        .copyWith(color: palette.muted)),
              ])),
          Text(item.mastery.label,
              style: context.texts.labelSmall
                  .copyWith(color: masteryTextColor(context, item.mastery))),
        ]));
  }
}
