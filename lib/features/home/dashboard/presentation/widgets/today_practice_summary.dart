import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class TodayPracticeSummary extends StatelessWidget {
  const TodayPracticeSummary({
    super.key,
    required this.completed,
    required this.goal,
    required this.total,
    required this.onEditGoal,
  });

  final int completed;
  final int goal;
  final int total;
  final VoidCallback onEditGoal;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;
    final accent = palette.primary;
    final safeGoal = goal < 1 ? 1 : goal;
    final progress = (completed / safeGoal).clamp(0.0, 1.0);
    final isComplete = completed >= safeGoal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '오늘 연습',
                  style: context.texts.headlineSmall
                      .copyWith(color: ink, letterSpacing: -0.4),
                ),
              ),
              if (isComplete) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.goodSoft,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 15, color: palette.good),
                      const SizedBox(width: 5),
                      Text(
                        '오늘 완료',
                        style: context.texts.labelSmall
                            .copyWith(color: palette.good),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '목표 수정',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEditGoal,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                ),
              ] else
                TextButton.icon(
                  onPressed: onEditGoal,
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('목표 설정'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completed',
                style:
                    context.texts.headlineLarge.copyWith(color: ink, height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 5, bottom: 3),
                child: Text(
                  '/ $safeGoal문장',
                  style: context.texts.bodyLarge.copyWith(color: muted),
                ),
              ),
              const Spacer(),
              Text(
                isComplete ? '목표 달성!' : '${safeGoal - completed}문장 남음',
                style: context.texts.bodySmall
                    .copyWith(color: isComplete ? palette.good : accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: palette.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(
                isComplete ? palette.good : accent,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
              const SizedBox(width: 7),
              Text(
                '지금까지 총 $total문장을 연습했어요',
                style: context.texts.bodySmall.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DailyGoalDialog extends StatefulWidget {
  const DailyGoalDialog({super.key, required this.initialGoal});

  final int initialGoal;

  @override
  State<DailyGoalDialog> createState() => _DailyGoalDialogState();
}

class _DailyGoalDialogState extends State<DailyGoalDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: '${widget.initialGoal}');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 1 || value > 100) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('오늘의 문장 목표'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('하루에 몇 문장을 따라 말할까요?'),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
            decoration: const InputDecoration(
              suffixText: '문장',
              border: OutlineInputBorder(),
              helperText: '1~100 사이로 설정할 수 있어요.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: submit, child: const Text('저장')),
      ],
    );
  }
}
