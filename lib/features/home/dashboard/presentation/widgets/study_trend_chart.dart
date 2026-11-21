// 날짜별 학습 그래프(사용자 요청). 학습 캘린더 아래에 둔다.
//
// 캘린더는 '어느 날 했는지'를 보여 준다. 칸 색은 네 단계뿐이라 15번 한 날과
// 50번 한 날이 같아 보인다. 그래프는 '얼마나 했는지'를 날짜별 높이로 보여
// 준다. 두 화면이 같은 기록(PracticeCalendar)을 읽으므로 수가 어긋나지
// 않는다.
//
// 따라 말하기와 단어 복습을 한 막대에 쌓는다. 하루 목표는 따라 말한 수로만
// 재지만(학습 캘린더와 같다), 그래프는 그날 얼마나 공부했는지를 묻는 것이라
// 둘을 함께 본다.

import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/content/practice_goal_text.dart';
import 'package:parrokit/core/shared/utils/calendar_date_label.dart';

/// 그래프 한 칸. 하루치다.
class StudyTrendDay {
  const StudyTrendDay({
    required this.date,
    required this.practiced,
    required this.words,
  });

  final DateTime date;

  /// 그날 따라 말한 횟수.
  final int practiced;

  /// 그날 복습한 단어 수.
  final int words;

  int get total => practiced + words;
  bool get isEmpty => total <= 0;
}

String studyTrendDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 오늘까지 [days]일치를 과거 → 오늘 순으로 만든다.
///
/// 기록이 없는 날도 0으로 넣는다. 빠뜨리면 쉰 날이 그래프에서 사라져서
/// 꾸준히 한 것처럼 보인다.
List<StudyTrendDay> studyTrendDays({
  required DateTime now,
  required int days,
  Map<String, int> practiceCounts = const {},
  Map<String, int> wordReviewCounts = const {},
}) {
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(days, (i) {
    final date = today.subtract(Duration(days: days - 1 - i));
    final key = studyTrendDateKey(date);
    return StudyTrendDay(
      date: date,
      practiced: practiceCounts[key] ?? 0,
      words: wordReviewCounts[key] ?? 0,
    );
  });
}

/// 고를 수 있는 기간.
const List<int> studyTrendRanges = [7, 14, 30];

String studyTrendRangeLabel(int days) => '$days일';

/// 기간 전체를 한 줄로 간추린다.
String studyTrendSummary(List<StudyTrendDay> days) {
  final practiced = days.fold<int>(0, (sum, d) => sum + d.practiced);
  final words = days.fold<int>(0, (sum, d) => sum + d.words);
  final studied = days.where((d) => !d.isEmpty).length;
  final parts = <String>[
    '학습 $studied일',
    '따라 말하기 $practiced$practiceCountUnit',
    if (words > 0) '단어 $words$wordReviewCountUnit',
  ];
  return parts.join(' · ');
}

/// 날짜 눈금을 몇 칸마다 적을지. 30일치에 날짜를 다 적으면 글자가 겹친다.
int studyTrendLabelStep(int days) {
  if (days <= 7) return 1;
  if (days <= 14) return 2;
  return 5;
}

const String studyTrendTitle = '학습 그래프';
const String studyTrendEmptyHint = '아직 기록이 없어요. 따라 말하거나 단어를 복습하면 쌓여요.';
const String studyTrendHint = '막대를 누르면 그날 한 양을 볼 수 있어요.';

/// 막대 하나를 읽어 주는 말. 화면 낭독과 길게 누르기 설명에 함께 쓴다.
///
/// 날짜는 앱의 한 규칙을 쓴다(해가 넘어가면 연도까지). 30일치를 보면
/// 연말에 작년 날짜가 섞이는데, 그때 '12월 28일'만 적으면 올해 것처럼 보인다.
String studyTrendDayLabel(StudyTrendDay day, {DateTime? now}) {
  final date = calendarDateLabel(day.date, now ?? DateTime.now());
  if (day.isEmpty) return '$date, 쉰 날';
  final parts = <String>[
    '따라 말하기 ${day.practiced}$practiceCountUnit',
    if (day.words > 0) '단어 ${day.words}$wordReviewCountUnit',
  ];
  return '$date, ${parts.join(', ')}';
}

class StudyTrendChart extends StatefulWidget {
  const StudyTrendChart({
    super.key,
    required this.practiceCounts,
    this.wordReviewCounts = const {},
    this.initialRange = 14,
    this.now,
  });

  final Map<String, int> practiceCounts;
  final Map<String, int> wordReviewCounts;
  final int initialRange;

  /// '오늘'로 볼 때. 테스트에서 고정한다.
  final DateTime? now;

  @override
  State<StudyTrendChart> createState() => _StudyTrendChartState();
}

class _StudyTrendChartState extends State<StudyTrendChart> {
  late int range = widget.initialRange;
  DateTime? selected;

  static const double _barAreaHeight = 120;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;

    final days = studyTrendDays(
      now: widget.now ?? DateTime.now(),
      days: range,
      practiceCounts: widget.practiceCounts,
      wordReviewCounts: widget.wordReviewCounts,
    );
    final peak = days.fold<int>(0, (max, d) => d.total > max ? d.total : max);
    final anyRecord = peak > 0;
    final labelStep = studyTrendLabelStep(range);
    final now = widget.now ?? DateTime.now();
    final chosen = selected == null
        ? null
        : days.where((d) => d.date == selected).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  studyTrendTitle,
                  style: context.texts.headlineSmall.copyWith(color: ink),
                ),
              ),
              ...studyTrendRanges.map((days) {
                final active = days == range;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Material(
                    color: active ? palette.primary : palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InkWell(
                      key: ValueKey('trend-range-$days'),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: active
                          ? null
                          : () => setState(() {
                                range = days;
                                selected = null;
                              }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Text(
                          studyTrendRangeLabel(days),
                          style: context.texts.labelSmall.copyWith(
                            color: active ? palette.onAccent : ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _barAreaHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days)
                  Expanded(
                    child: _Bar(
                      day: day,
                      peak: peak,
                      areaHeight: _barAreaHeight,
                      chosen: day.date == selected,
                      now: now,
                      // accent는 primary와 같은 파랑이라(app_tokens) 쌓은
                      // 막대 두 칸이 한 덩어리로 보였다. 초록을 쓴다.
                      practiceColor: palette.primary,
                      wordColor: palette.good,
                      emptyColor: palette.surfaceAlt,
                      outline: ink,
                      onTap: () => setState(
                          () => selected = day.date == selected ? null : day.date),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Text(
                    // 오늘은 늘 적는다. 그 앞은 눈금 간격마다.
                    i == days.length - 1 || (days.length - 1 - i) % labelStep == 0
                        ? '${days[i].date.day}'
                        : '',
                    textAlign: TextAlign.center,
                    style: context.texts.labelSmall.copyWith(
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _LegendDot(color: palette.primary, label: '따라 말하기'),
              _LegendDot(color: palette.good, label: '단어 복습'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            !anyRecord
                ? studyTrendEmptyHint
                : chosen == null
                    ? '${studyTrendSummary(days)}\n$studyTrendHint'
                    : studyTrendDayLabel(chosen, now: now),
            key: const ValueKey('trend-summary'),
            style: context.texts.labelSmall.copyWith(color: muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.now,
    required this.peak,
    required this.areaHeight,
    required this.chosen,
    required this.practiceColor,
    required this.wordColor,
    required this.emptyColor,
    required this.outline,
    required this.onTap,
  });

  final StudyTrendDay day;
  final DateTime now;
  final int peak;
  final double areaHeight;
  final bool chosen;
  final Color practiceColor;
  final Color wordColor;
  final Color emptyColor;
  final Color outline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 쉰 날도 눌러서 확인할 수 있게 얇은 자리를 남긴다.
    const emptyHeight = 4.0;
    final scale = peak <= 0 ? 0.0 : (areaHeight - 8) / peak;
    final practiceHeight = day.practiced * scale;
    final wordHeight = day.words * scale;
    final label = studyTrendDayLabel(day, now: now);

    return Semantics(
      label: label,
      selected: chosen,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (day.isEmpty)
                  _Segment(
                    height: emptyHeight,
                    color: emptyColor,
                    top: true,
                    bottom: true,
                  )
                else ...[
                  if (wordHeight > 0)
                    _Segment(height: wordHeight, color: wordColor, top: true),
                  if (practiceHeight > 0)
                    _Segment(
                      height: practiceHeight,
                      color: practiceColor,
                      top: wordHeight <= 0,
                      bottom: true,
                    ),
                ],
                if (chosen) ...[
                  const SizedBox(height: 3),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.height,
    required this.color,
    this.top = false,
    this.bottom = false,
  });

  final double height;
  final Color color;
  final bool top;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(3);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: top ? radius : Radius.zero,
          topRight: top ? radius : Radius.zero,
          bottomLeft: bottom ? radius : Radius.zero,
          bottomRight: bottom ? radius : Radius.zero,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.texts.labelSmall
              .copyWith(color: HomeTokens.of(context).muted),
        ),
      ],
    );
  }
}
