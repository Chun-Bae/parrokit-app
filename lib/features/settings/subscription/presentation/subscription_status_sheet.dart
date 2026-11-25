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

  /// 시트를 닫고 [action]을 한다(5차).
  ///
  /// 복원도 관리도 결과를 토스트로 알린다. 토스트는 화면의 Scaffold가 그리는
  /// SnackBar라 시트 뒤 맨 아래에 깔린다 - 시트를 열어 둔 채로 띄우면
  /// '복원할 구독을 찾지 못했어요'가 보이지 않고, 눌러도 아무 일이 없는
  /// 것처럼 보인다. [action]은 이 시트를 연 화면의 context를 들고 있으므로
  /// 시트를 닫은 뒤에 불러도 된다.
  void _close(BuildContext context, VoidCallback action) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    action();
  }

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
            if (!isTopTier(state.tier))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  key: const ValueKey('status-upgrade'),
                  onPressed:
                      onUpgrade == null ? null : () => _close(context, onUpgrade!),
                  child: const Text(subscriptionUpgradeLabel),
                ),
              ),
            OutlinedButton(
              key: const ValueKey('status-manage'),
              onPressed:
                  onManage == null ? null : () => _close(context, onManage!),
              child: const Text(subscriptionManageLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('status-restore'),
              onPressed:
                  onRestore == null ? null : () => _close(context, onRestore!),
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
