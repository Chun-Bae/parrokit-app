// 더보기의 '구독' 줄. 지금 단계를 보여 주고 누르면 구독 화면을 연다.
//
// 구독 화면은 PaywallPresenter가 고른다 — 출시 빌드는 RevenueCat Paywall,
// 개발 빌드는 우리 미리보기(스토어 상품이 준비되기 전까지).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_actions.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_status_sheet.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';
import '../widgets/nav_tile.dart';

class SubscriptionSection extends StatelessWidget {
  const SubscriptionSection({super.key, this.presenter});

  /// 테스트에서 가짜를 넣기 위한 자리. 비우면 빌드에 맞는 것을 고른다.
  final PaywallPresenter? presenter;

  @override
  Widget build(BuildContext context) {
    // 단계는 서버가 정한다. 예전 1회 구매(광고 제거)는 단계를 올리지 않고
    // 광고만 없앤다.
    final subscription = context.watch<SubscriptionProvider>();
    final tier = subscription.tier;
    final paywall = presenter ?? resolvePaywallPresenter();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: NavTile(
        key: const ValueKey('subscription-row'),
        icon: Icons.workspace_premium_outlined,
        iconAsset: subscriptionTierIconAsset(tier),
        title: subscriptionScreenTitle,
        subtitle: subscriptionRowSubtitle(tier),
        trailing: Text(
          subscriptionTierName(tier),
          key: const ValueKey('subscription-tier-name'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        // 구독 중이면 고르는 화면이 아니라 지금 상태와 관리로 간다(5차 4단계).
        onTap: () => subscription.isSubscribed
            ? showSubscriptionStatusSheet(
                context,
                onManage: () => openStoreSubscriptions(context),
                onRestore: () => restorePurchases(context),
                onUpgrade: tier == SubscriptionTier.light
                    ? () => paywall.show(context)
                    : null,
              )
            : paywall.show(context),
      ),
    );
  }
}
