import 'package:flutter/material.dart';

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
    const ink = Color(0xFF24364F);
    const muted = Color(0xFF61758D);
    const accent = Color(0xFF4F6EAF);
    final safeGoal = goal < 1 ? 1 : goal;
    final progress = (completed / safeGoal).clamp(0.0, 1.0);
    final isComplete = completed >= safeGoal;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '오늘 연습',
                  style: TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              if (isComplete) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDEFEA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 15, color: Color(0xFF477B70)),
                      SizedBox(width: 5),
                      Text(
                        '오늘 완료',
                        style: TextStyle(
                          color: Color(0xFF477B70),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
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
                style: const TextStyle(
                  color: ink,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 5, bottom: 3),
                child: Text(
                  '/ $safeGoal문장',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                isComplete ? '목표 달성!' : '${safeGoal - completed}문장 남음',
                style: TextStyle(
                  color: isComplete ? const Color(0xFF477B70) : accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFE8EFF7),
              valueColor: AlwaysStoppedAnimation(
                isComplete ? const Color(0xFF6FA69A) : accent,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
              const SizedBox(width: 7),
              Text(
                '지금까지 총 $total문장을 연습했어요',
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
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
