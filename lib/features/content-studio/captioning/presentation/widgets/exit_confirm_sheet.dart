// ============================================================================
// lib/features/_content/clip_editor/presentation/widgets/exit_confirm_sheet.dart
// ============================================================================
//
// [역할]
// 편집 종료 확인 바텀시트 위젯.
//
// [레이어]
// Presentation Layer > Widgets
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 편집 종료 확인 바텀시트를 표시합니다.
///
/// [true]를 반환하면 나가기, [false]를 반환하면 계속 편집.
Future<bool?> showExitConfirmSheet(BuildContext context) {
  return showAppSheet<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: cs.error,
              ),
              const SizedBox(height: 16),
              Text(
                '편집을 취소하시겠습니까?',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '지금 나가면 입력한 모든 내용이 삭제됩니다.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('계속 편집'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('나가기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
