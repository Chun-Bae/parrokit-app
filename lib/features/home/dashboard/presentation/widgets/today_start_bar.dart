import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 새 디자인 홈의 "오늘" 한 줄. 무대 바로 아래에 오늘 목표 진행과 학습 시작
/// 버튼을 함께 둔다. 전에는 학습하러 가기 버튼이 내 문장 기록 카드 아래에
/// 있어서 한 화면을 내려야 보였고, 오늘 목표는 맨 아래 캘린더에만 있었다.
class TodayStartBar extends StatelessWidget {
  const TodayStartBar({
    super.key,
    required this.completed,
    required this.goal,
    required this.onStart,
  });

  final int completed;
  final int goal;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final safeGoal = goal < 1 ? 1 : goal;
    final done = completed >= safeGoal;
    final progress = (completed / safeGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(done ? '오늘 목표 완료' : '오늘 목표',
                  style: context.texts.labelMedium
                      .copyWith(color: done ? palette.good : palette.muted)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '$completed',
                      style: context.texts.headlineSmall.copyWith(
                          color: palette.ink, fontWeight: FontWeight.w800)),
                  TextSpan(
                      text: ' / $safeGoal 문장',
                      style: context.texts.bodyMedium
                          .copyWith(color: palette.muted)),
                ]),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.track),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: done ? palette.good : palette.primary,
                  backgroundColor: palette.surfaceAlt,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        FilledButton.icon(
          key: const ValueKey('today-start'),
          onPressed: onStart,
          style: FilledButton.styleFrom(
            backgroundColor: palette.accent,
            foregroundColor: palette.onAccent,
            iconColor: palette.onAccent,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('학습하기',
              style:
                  context.texts.titleMedium.copyWith(color: palette.onAccent)),
        ),
      ]),
    );
  }
}
