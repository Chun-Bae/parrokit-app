import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class StudyGardenPreview extends StatefulWidget {
  const StudyGardenPreview({
    super.key,
    required this.practiceCounts,
    required this.practiceGoals,
    required this.dailyGoal,
    required this.totalPracticed,
  });

  final Map<String, int> practiceCounts;
  final Map<String, int> practiceGoals;
  final int dailyGoal;
  final int totalPracticed;

  @override
  State<StudyGardenPreview> createState() => _StudyGardenPreviewState();
}

class _StudyGardenPreviewState extends State<StudyGardenPreview> {
  late final DateTime today;
  late DateTime month;
  DateTime? selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    month = DateTime(today.year, today.month);
  }

  String dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int countFor(DateTime date) => widget.practiceCounts[dateKey(date)] ?? 0;

  int goalFor(DateTime date) =>
      widget.practiceGoals[dateKey(date)] ?? widget.dailyGoal;

  int intensity(DateTime date) {
    final count = countFor(date);
    if (count <= 0) return 0;
    final storedGoal = goalFor(date);
    final goal = storedGoal < 1 ? 1 : storedGoal;
    final ratio = count / goal;
    if (ratio >= 1) return 4;
    if (ratio >= 0.66) return 3;
    if (ratio >= 0.33) return 2;
    return 1;
  }

  void moveMonth(int offset) {
    setState(() {
      month = DateTime(month.year, month.month + offset);
      selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;
    final levels = palette.garden;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday % 7;
    final cells = ((offset + days + 6) ~/ 7) * 7;
    final monthDates =
        List.generate(days, (i) => DateTime(month.year, month.month, i + 1));
    final activeDays = monthDates.where((date) => countFor(date) > 0).length;
    final completedDays =
        monthDates.where((date) => countFor(date) >= goalFor(date)).length;
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;
    final selectedCount = selected == null ? null : countFor(selected!);

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
                  '학습 캘린더',
                  style: context.texts.headlineSmall.copyWith(color: ink),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '누적 ${widget.totalPracticed}문장',
                  style: context.texts.labelSmall.copyWith(color: ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '연습한 문장이 많을수록 날짜가 진해져요.',
            style: context.texts.bodySmall.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                tooltip: '이전 달',
                onPressed: () => moveMonth(-1),
                icon: Icon(Icons.chevron_left_rounded, color: ink),
              ),
              Expanded(
                child: Text(
                  '${month.year}년 ${month.month}월',
                  textAlign: TextAlign.center,
                  style: context.texts.titleMedium.copyWith(color: ink),
                ),
              ),
              IconButton(
                tooltip: '다음 달',
                onPressed: isCurrentMonth ? null : () => moveMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .map(
                  (day) => Expanded(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: context.texts.labelSmall.copyWith(color: muted),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final day = index - offset + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final date = DateTime(month.year, month.month, day);
              final future = date.isAfter(today);
              final count = countFor(date);
              final goal = goalFor(date);
              final level = intensity(date);
              final current = date == today;
              final chosen = date == selected;
              final complete = count >= goal;
              final label = future
                  ? '${date.month}월 $day일, 아직 오지 않은 날'
                  : '${date.month}월 $day일, $count문장 연습${complete ? ', 목표 완료' : ''}';

              return Semantics(
                label: label,
                selected: chosen,
                excludeSemantics: true,
                child: Tooltip(
                  message: label,
                  child: Material(
                    color: levels[level].withValues(alpha: future ? 0.4 : 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                      side: BorderSide(
                        color: chosen || current ? ink : Colors.transparent,
                        width: chosen ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap:
                          future ? null : () => setState(() => selected = date),
                      child: Center(
                        child: complete
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : Text(
                                '$day',
                                style: context.texts.bodySmall.copyWith(
                                  color: level >= 3
                                      ? Colors.white
                                      : ink.withValues(
                                          alpha: future ? 0.3 : 1,
                                        ),
                                  fontWeight: current
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 14,
            runSpacing: 8,
            children: [
              Text(
                '학습 $activeDays일 · 목표 완료 $completedDays일',
                style: context.texts.bodySmall.copyWith(color: ink),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('적게',
                      style: context.texts.labelSmall.copyWith(color: muted)),
                  const SizedBox(width: 5),
                  ...levels.map(
                    (color) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Text('완료',
                      style: context.texts.labelSmall.copyWith(color: muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            selected == null
                ? '날짜를 누르면 그날 연습한 문장 수를 볼 수 있어요.'
                : '${selected!.month}월 ${selected!.day}일 · $selectedCount / ${goalFor(selected!)}문장${selectedCount! >= goalFor(selected!) ? ' · 목표 완료' : ''}',
            style: context.texts.labelSmall.copyWith(color: muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
