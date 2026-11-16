// 구독 고르기 미리보기. 스토어 상품과 RevenueCat Paywall이 준비되기 전까지
// 쓰는 화면이다(개발 빌드 전용). 진짜 Paywall로 바꾸는 것은 PaywallPresenter
// 한 줄이면 된다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

Future<void> showSubscriptionPreviewSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => const SubscriptionPreviewSheet(),
  );
}

class SubscriptionPreviewSheet extends StatefulWidget {
  const SubscriptionPreviewSheet({super.key});

  @override
  State<SubscriptionPreviewSheet> createState() =>
      _SubscriptionPreviewSheetState();
}

class _SubscriptionPreviewSheetState extends State<SubscriptionPreviewSheet> {
  /// 누른 결과를 시트 안에 적는다(5차 370).
  ///
  /// 전에는 토스트로 알렸는데 이 화면은 바텀시트라 시트가 아래를 덮어
  /// 보이지 않았다(368·369에서 다른 시트로 확인).
  String? note;

  void _say(String message) => setState(() => note = message);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subscriptionScreenTitle, style: context.texts.titleLarge),
            const SizedBox(height: 16),
            Text(subscriptionFreeHeadline, style: context.texts.titleMedium),
            const SizedBox(height: 4),
            Text(
              subscriptionFreeBody,
              style: context.texts.bodyReading
                  .copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final copy in subscriptionTiers) ...[
              _TierCard(
                  copy: copy, onStart: () => _say(subscriptionNotReadyToast)),
              const SizedBox(height: 12),
            ],
            Text(
              subscriptionRenewalNotice,
              style: context.texts.bodySmall
                  .copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 4),
            Text(
              subscriptionParrotNotice,
              style: context.texts.bodySmall
                  .copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const ValueKey('subscription-restore'),
              onPressed: () => _say(subscriptionNotReadyToast),
              child: const Text(subscriptionRestoreLabel),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  note!,
                  key: const ValueKey('subscription-preview-note'),
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall.copyWith(color: cs.error),
                ),
              ),
            const SizedBox(height: 4),
            // 미리보기라는 것을 숨기지 않는다.
            Text(
              subscriptionPreviewNotice,
              key: const ValueKey('subscription-preview-notice'),
              textAlign: TextAlign.center,
              style: context.texts.bodySmall.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.copy, required this.onStart});

  final SubscriptionTierCopy copy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(copy.name, style: context.texts.titleMedium),
              const Spacer(),
              Text(copy.previewPrice,
                  style: context.texts.titleMedium
                      .copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          for (final benefit in copy.benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(benefit,
                  style: context.texts.bodyReading
                      .copyWith(color: cs.onSurface)),
            ),
          const SizedBox(height: 10),
          FilledButton(
            key: ValueKey('start-${copy.tier.name}'),
            onPressed: onStart,
            child: Text(copy.startLabel),
          ),
        ],
      ),
    );
  }
}
