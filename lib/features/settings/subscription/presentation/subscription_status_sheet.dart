// 구독 중일 때 더보기 '구독' 줄을 누르면 열리는 화면(5차 4단계).
//
// 지금 단계, 다음 결제일, 이번 달 남은 패롯, 서버 백업을 보여 주고
// 스토어 구독 화면과 구매 복원으로 간다. 값은 모두 서버가 정한 것을 읽는다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_quota.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

Future<void> showSubscriptionStatusSheet(
  BuildContext context, {
  VoidCallback? onManage,
  VoidCallback? onRestore,
  VoidCallback? onUpgrade,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => SubscriptionStatusSheet(
      onManage: onManage,
      onRestore: onRestore,
      onUpgrade: onUpgrade,
    ),
  );
}

/// 단계별로 매달 받는 패롯. 구독 고르기 화면에 적은 것과 같은 수다.
int monthlyParrotsFor(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return 0;
    case SubscriptionTier.light:
      return 100;
    case SubscriptionTier.pro:
      return 400;
  }
}

String formatStorageBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

class SubscriptionStatusSheet extends StatelessWidget {
  const SubscriptionStatusSheet({
    super.key,
    this.onManage,
    this.onRestore,
    this.onUpgrade,
  });

  final VoidCallback? onManage;
  final VoidCallback? onRestore;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subscription = context.watch<SubscriptionProvider>();
    final state = subscription.state;
    final user = context.watch<UserProvider>().currentUser;

    final monthly = monthlyParrotsFor(state.tier);
    final leftParrots = user?.subParrots ?? 0;
    final usedStorage = subscription.storageUsedBytes ?? 0;
    final quota = serverStorageQuotaBytes(state.tier);
    final renewal = subscriptionRenewalLine(state.periodEnd);
    final notice = subscriptionStatusNotice(state.status, state.periodEnd);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subscriptionTierName(state.tier),
                key: const ValueKey('status-tier-name'),
                style: context.texts.titleLarge),
            if (renewal != null) ...[
              const SizedBox(height: 4),
              Text(renewal,
                  key: const ValueKey('status-renewal'),
                  style: context.texts.bodyMedium
                      .copyWith(color: cs.onSurfaceVariant)),
            ],
            if (notice != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('status-notice'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(notice, style: context.texts.bodySmall),
              ),
            ],
            const SizedBox(height: 20),
            _MeterRow(
              title: subscriptionParrotRowTitle,
              valueText: subscriptionRemainingText(leftParrots, monthly),
              progress: monthly == 0 ? 0 : leftParrots / monthly,
              rowKey: const ValueKey('status-parrots'),
            ),
            const SizedBox(height: 14),
            _MeterRow(
              title: subscriptionStorageRowTitle,
              valueText:
                  '${formatStorageBytes(usedStorage)} / ${formatStorageBytes(quota)}',
              progress: quota == 0 ? 0 : usedStorage / quota,
              rowKey: const ValueKey('status-storage'),
            ),
            const SizedBox(height: 10),
            Text(subscriptionParrotNotice,
                style: context.texts.bodySmall
                    .copyWith(color: cs.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 20),
            if (state.tier == SubscriptionTier.light)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  key: const ValueKey('status-upgrade'),
                  onPressed: onUpgrade,
                  child: const Text(subscriptionUpgradeLabel),
                ),
              ),
            OutlinedButton(
              key: const ValueKey('status-manage'),
              onPressed: onManage,
              child: const Text(subscriptionManageLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('status-restore'),
              onPressed: onRestore,
              child: const Text(subscriptionRestoreButtonLabel),
            ),
            const SizedBox(height: 4),
            Text(subscriptionRenewalNotice,
                style: context.texts.bodySmall
                    .copyWith(color: cs.onSurfaceVariant, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _MeterRow extends StatelessWidget {
  const _MeterRow({
    required this.title,
    required this.valueText,
    required this.progress,
    required this.rowKey,
  });

  final String title;
  final String valueText;
  final double progress;
  final Key rowKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // labelLarge는 버튼 글자용이라 색이 onPrimary다(흰 바탕에서 안 보였다).
            Expanded(
                child: Text(title,
                    style: context.texts.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface))),
            Text(valueText,
                style: context.texts.labelMedium
                    .copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.track),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
