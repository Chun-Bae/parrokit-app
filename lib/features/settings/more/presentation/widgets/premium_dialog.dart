// ============================================================================
// lib/features/more/presentation/premium_dialog.dart
// ============================================================================
//
// [역할]
// 프리미엄(광고 제거) 구매 다이얼로그.
//
// [레이어]
// Presentation Layer - Dialog
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 프리미엄 구매 다이얼로그 표시.
Future<void> showPremiumDialog(
  BuildContext context, {
  String price = 'US\$0.99',
  VoidCallback? onBuy,
  VoidCallback? onRestore,
}) {
  return showDialog(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      final buttonTextStyle = tt.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      );
      const buttonHeight = 48.0;
      const buttonPadding = EdgeInsets.symmetric(vertical: 4);

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: cs.surface,
        title: Text(
          '프리미엄 (광고 제거)',
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '광고 노출 위치',
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const _Bullet(
              text: '쇼츠: 다음 영상으로 넘길 때 주기적으로 전면 광고',
            ),
            const _Bullet(
              text: '프리미엄 구입 시 모든 광고가 비활성화됩니다',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(buttonHeight),
                  padding: buttonPadding,
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  side: BorderSide(color: cs.outlineVariant),
                  textStyle: buttonTextStyle,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onBuy?.call();
                },
                child: Text('$price 결제하기'),
              ),
            ),
            if (onRestore != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(buttonHeight),
                    padding: buttonPadding,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    side: BorderSide(color: cs.outlineVariant),
                    foregroundColor: cs.onSurface,
                    textStyle: buttonTextStyle,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onRestore.call();
                  },
                  child: const Text('구매 내역 복원'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(buttonHeight),
                  padding: buttonPadding,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  foregroundColor: cs.primary,
                  textStyle: buttonTextStyle,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('나중에'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// 불릿 포인트 위젯.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
