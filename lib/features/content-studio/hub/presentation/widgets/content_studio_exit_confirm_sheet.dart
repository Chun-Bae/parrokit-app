import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

Future<bool?> showContentStudioExitConfirmSheet(BuildContext context) {
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
                '콘텐츠 제작에서 나갈까요?',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '지금 나가면 이 탭에서 하던 작업은 이어서 볼 수 없어요.',
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
                      child: const Text('계속 보기'),
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
