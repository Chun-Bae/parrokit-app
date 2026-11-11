// ============================================================================
// lib/features/_content/clip_editor/presentation/widgets/stt_progress_card.dart
// ============================================================================
//
// [역할]
// STT 진행 상황 표시 카드 위젯.
//
// [레이어]
// Presentation Layer > Widgets
// ============================================================================

import 'package:flutter/material.dart';

import '../models/edit_state.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// STT 진행 상황 표시 카드.
class SttProgressCard extends StatelessWidget {
  const SttProgressCard({
    super.key,
    required this.sttState,
    required this.sttProgress,
    required this.sttTotal,
  });

  final SttProcessState sttState;
  final int sttProgress;
  final int sttTotal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 번역 중일 때 배치 진행률 표시
    final translatingLabel =
        sttTotal > 0 && sttState == SttProcessState.translating
            ? '번역 중 ($sttProgress/$sttTotal)'
            : '번역 중';

    final steps = [
      (SttProcessState.extracting, '오디오 추출', Icons.music_note_rounded),
      (SttProcessState.transcribing, '음성 인식 (STT)', Icons.hearing_rounded),
      (SttProcessState.translating, translatingLabel, Icons.translate_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI 자막 생성 중...',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.map((step) {
            final (state, label, icon) = step;
            final isActive = sttState == state;
            final isCompleted = sttState.index > state.index;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (isCompleted)
                    Icon(Icons.check_circle, color: cs.primary, size: 20)
                  else if (isActive)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  else
                    Icon(Icons.circle_outlined,
                        color: cs.onSurface.withValues(alpha: 0.3), size: 20),
                  const SizedBox(width: 12),
                  Icon(icon,
                      size: 18,
                      color: isActive || isCompleted
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive || isCompleted
                              ? cs.onSurface
                              : cs.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
