// 구독 고르기 미리보기. 스토어 상품과 RevenueCat Paywall이 준비되기 전까지
// 쓰는 화면이다(개발 빌드 전용). 진짜 Paywall로 바꾸는 것은 PaywallPresenter
// 한 줄이면 된다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/features/settings/shared/store_badges.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_actions.dart';
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
            // 살 수 없다는 것을 카드보다 먼저 말한다(5차 448). 전에는 이
            // 안내가 맨 아래 흐린 글씨였고, 두 '시작하기'는 파란 버튼이라
            // 살 수 있어 보였다. 누른 뒤에야 없다고 알려 줬다.
            Container(
              key: const ValueKey('subscription-preview-notice'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                subscriptionPreviewNotice,
                style: context.texts.bodySmall
                    .copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            for (final copy in subscriptionTiers) ...[
              _TierCard(copy: copy),
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
            // 복원은 눌린다(5차).
            //
            // 전에는 '시작하기'와 함께 꺼 두고 '까닭은 위에 적었다'고 했다.
            // 그런데 위 안내는 **살 상품이 없다**는 말이고, 이 줄은 **이미
            // 산 사람**에게 하는 말이다. 게다가 안내는 카드 넷 위에 있어
            // 여기까지 내려오면 화면 밖이다. 시뮬레이터에서 눌러 보니
            // 아무 일도 일어나지 않았다 - 왜 안 되는지 알 길이 없다
            // (프로필·환전소·플레이어는 이미 '눌리면 까닭을 말해 준다').
            //
            // 복원은 상품 목록과 상관없다. RevenueCat의 restorePurchases는
            // 스토어의 구매 내역을 가져오는 것이라, 상품이 아직 없어도
            // 부를 수 있다. 찾은 것이 없으면 '복원할 구독을 찾지 못했어요',
            // 못 다녀오면 '구매를 복원하지 못했어요'라고 말해 준다.
            TextButton(
              key: const ValueKey('subscription-restore'),
              onPressed: () => _restore(context),
              child: const Text(subscriptionRestoreLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// 시트를 닫고 복원한다.
  ///
  /// 닫는 것이 먼저다. 토스트는 ScaffoldMessenger가 띄우는 SnackBar인데
  /// 그 자리는 화면의 Scaffold다. 이 시트는 root navigator 위에 뜨므로
  /// (showAppSheet, 탭 바가 있는 화면), 열어 둔 채로 띄우면 결과가 시트
  /// 뒤에 가려 보이지 않는다 - 눌러도 아무 일이 없는 것과 같다.
  /// 시뮬레이터에서 토스트 로그만 남고 화면에는 안 나왔다(5차).
  void _restore(BuildContext context) {
    Navigator.of(context).pop();
    // 시트의 context는 방금 죽었다. 살아 있는 화면 쪽으로 부른다.
    final root = rootNavigatorKey.currentContext;
    if (root == null) return;
    restorePurchases(root);
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.copy});

  final SubscriptionTierCopy copy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badge = subscriptionTierBadgeOf(copy.tier);
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
              // 어느 단계인지 이름 앞에서 바로 보이게 한다(5차 465).
              // 더보기 '구독' 줄과 같은 그림이다.
              StoreBadgeIcon(
                key: ValueKey('tier-badge-${copy.tier.name}'),
                badge: badge,
                size: 22,
              ),
              const SizedBox(width: 8),
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
                  style:
                      context.texts.bodyReading.copyWith(color: cs.onSurface)),
            ),
          const SizedBox(height: 10),
          // 상품이 없으니 눌리지 않는다. 이름은 그대로 두어 무엇이
          // 생길지는 보이게 한다.
          FilledButton(
            key: ValueKey('start-${copy.tier.name}'),
            onPressed: null,
            child: Text(copy.startLabel),
          ),
        ],
      ),
    );
  }
}
