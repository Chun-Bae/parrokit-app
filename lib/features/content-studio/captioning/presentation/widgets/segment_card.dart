import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:video_player/video_player.dart';

import '../../domain/utils/timecode_service.dart';
import 'labeled_text_field.dart';
import 'time_triplet_field.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class SegmentCard extends StatelessWidget {
  const SegmentCard({
    super.key,
    required this.playerController,
    required this.startCtl,
    required this.endCtl,
    required this.originalCtl,
    required this.pronCtl,
    required this.koCtl,
    this.onStartCommitted,
    this.onEndCommitted,
    this.onRangeUpdated,
    this.enabled = true,
    this.onDelete,
  });

  final VideoPlayerController? playerController;
  final TextEditingController startCtl;
  final TextEditingController endCtl;
  final TextEditingController originalCtl;
  final TextEditingController pronCtl;
  final TextEditingController koCtl;
  final VoidCallback? onStartCommitted;
  final VoidCallback? onEndCommitted;
  final VoidCallback? onRangeUpdated;
  final bool enabled;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _SegmentTimeButton(
                          label: 'A',
                          onPressed: _registerA,
                          color: theme.colorScheme.primary,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 4),
                        TimeTripletField(
                          label: '시작',
                          target: startCtl,
                          showGuide: false,
                          compact: true,
                          onCommitted: onStartCommitted,
                        ),
                        const SizedBox(width: 8),
                        _SegmentTimeButton(
                          label: 'B',
                          onPressed: _registerB,
                          color: theme.colorScheme.primary,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 4),
                        TimeTripletField(
                          label: '끝',
                          target: endCtl,
                          showGuide: false,
                          compact: true,
                          onCommitted: onEndCommitted,
                        ),
                        const SizedBox(width: 8),
                        if (onDelete != null)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Material(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: onDelete,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.8),
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '삭제',
                                style: context.texts.labelSmall.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LabeledTextField(
                    label: '원문',
                    hint: '원문 입력',
                    controller: originalCtl,
                    clearable: true,
                    horizontal: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LabeledTextField(
                    label: '해석',
                    hint: '해석 입력',
                    controller: koCtl,
                    clearable: true,
                    horizontal: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LabeledTextField(
                    label: '발음',
                    hint: '발음 입력',
                    controller: pronCtl,
                    clearable: true,
                    horizontal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _registerA() {
    final ms = _currentPositionMs();
    if (ms == null) return;

    final next = TimecodeService().msToMMSSmmm(ms);
    final currentB = _parseMs(endCtl.text);
    if (currentB != null && ms > currentB) {
      endCtl.text = next;
    }
    startCtl.text = next;
    onRangeUpdated?.call();
  }

  void _registerB() {
    final ms = _currentPositionMs();
    if (ms == null) return;

    final next = TimecodeService().msToMMSSmmm(ms);
    final currentA = _parseMs(startCtl.text);
    if (currentA != null && ms < currentA) {
      startCtl.text = next;
    }
    endCtl.text = next;
    onRangeUpdated?.call();
  }

  int? _currentPositionMs() {
    final c = playerController;
    if (c == null || !c.value.isInitialized) {
      showToast('재생 위치를 확인할 수 없습니다.');
      return null;
    }
    return c.value.position.inMilliseconds;
  }

  int? _parseMs(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    try {
      return TimecodeService().parseToMs(text);
    } catch (_) {
      return null;
    }
  }
}

class _SegmentTimeButton extends StatelessWidget {
  const _SegmentTimeButton({
    required this.label,
    required this.onPressed,
    required this.color,
    required this.isDark,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final symbol = label.isNotEmpty ? label.substring(0, 1) : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Text(
                symbol,
                style: context.texts.bodyMedium.copyWith(color: color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '추가',
          style: context.texts.labelSmall.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}
