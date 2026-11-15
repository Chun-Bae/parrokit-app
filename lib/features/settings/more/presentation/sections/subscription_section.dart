// 더보기의 '구독' 줄. 지금 단계를 보여 주고 누르면 구독 화면을 연다.
//
// 구독 화면은 PaywallPresenter가 고른다 — 출시 빌드는 RevenueCat Paywall,
// 개발 빌드는 우리 미리보기(스토어 상품이 준비되기 전까지).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';
import '../widgets/nav_tile.dart';

class SubscriptionSection extends StatelessWidget {
  const SubscriptionSection({super.key, this.presenter});

  /// 테스트에서 가짜를 넣기 위한 자리. 비우면 빌드에 맞는 것을 고른다.
  final PaywallPresenter? presenter;

  @override
  Widget build(BuildContext context) {
    final adsRemoved = context.watch<IapProvider>().isPremium;
    final tier = currentSubscriptionTier(adsRemoved: adsRemoved);
    final paywall = presenter ?? resolvePaywallPresenter();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: NavTile(
        key: const ValueKey('subscription-row'),
        icon: Icons.workspace_premium_outlined,
        title: subscriptionScreenTitle,
        subtitle: subscriptionRowSubtitle(tier),
        trailing: Text(
          subscriptionTierName(tier),
          key: const ValueKey('subscription-tier-name'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        onTap: () => paywall.show(context),
      ),
    );
  }
}
