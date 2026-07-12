// ============================================================================
// lib/features/content-studio/captioning/presentation/widgets/stt_confirm_dialog.dart
// ============================================================================
//
// [역할]
// STT 시작 전 코인 소모 안내 + ASR 엔진 선택 다이얼로그.
//
// [레이어]
// Presentation Layer > Widgets
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';

import '../../data/adapters/asr_engine.dart';
import '../providers/captioning_provider.dart';
import 'stt_progress_card.dart';

/// STT 시작 전 안내 다이얼로그를 표시하고 진행 상황 위젯을 바텀시트 내에서 보여줍니다.
Future<void> showSttConfirmDialog(
  BuildContext context, {
  required CaptioningProvider vm,
  AsrEngine initial = AsrEngine.whisper,
}) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final bg = isDark ? AppColors.surfaceContainerDark : AppColors.surface;
  const visibleEngines = [AsrEngine.whisper];

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    showDragHandle: false,
    builder: (ctx) {
      AsrEngine selected =
          visibleEngines.contains(initial) ? initial : AsrEngine.whisper;
      final cs = Theme.of(ctx).colorScheme;

      return ListenableBuilder(
        listenable: vm,
        builder: (ctx, _) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: 24 + MediaQuery.of(ctx).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: vm.isSttProcessing
                  ? Column(
                      key: const ValueKey('progress'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '자동 자막 생성 중',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 16),
                        SttProgressCard(
                          sttState: vm.sttState,
                          sttProgress: vm.sttProgress,
                          sttTotal: vm.sttTotal,
                        ),
                      ],
                    )
                  : StatefulBuilder(
                      key: const ValueKey('confirm'),
                      builder: (ctx, setState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '자막 자동 생성',
                              style:
                                  Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '영상의 음성을 분석해 자막 초안을 자동 생성합니다.',
                              style:
                                  Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                        color: isDark
                                            ? AppColors.textTertiaryDark
                                            : AppColors.textSecondary,
                                      ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '10초당 1패롯 소모',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ...visibleEngines.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _ModelOptionCard(
                                  title: e.label,
                                  description: e.description,
                                  isSelected: selected == e,
                                  accentColor: cs.primary,
                                  onTap: () => setState(() => selected = e),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('취소'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: vm.isSttProcessing
                                      ? null
                                      : () async {
                                          await vm.startStt(selected);
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                      backgroundColor: cs.primary),
                                  child: const Text('시작'),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ), // Ends AnimatedSwitcher
          ); // Ends Container
        },
      );
    },
  );
}

class _ModelOptionCard extends StatelessWidget {
  const _ModelOptionCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? (isSelected
            ? accentColor.withValues(alpha: 0.1)
            : AppColors.surfaceContainerHighDark)
        : (isSelected
            ? accentColor.withValues(alpha: 0.05)
            : AppColors.surfaceContainerHigh);

    final borderColor = isSelected
        ? accentColor
        : (isDark ? AppColors.dividerSubtleDark : AppColors.dividerSubtle);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? (isDark ? Colors.white : accentColor)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : (isDark
                          ? AppColors.textDisabledDark
                          : AppColors.textDisabled),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
