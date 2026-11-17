// 더보기의 '광고 제거' 줄(5차 463).
//
// 광고 제거는 한 번 사는 상품이라 매달 내는 구독과 다른데, 더보기에
// 입구가 아예 없었다. 상품(com.bull.parrokit.remove_ads)과 entitlement는
// 있는데 앱에서 살 길이 끊겨 있었다. PaymentSection이라는 위젯이 남아
// 있었지만 어느 화면도 쓰지 않는 죽은 코드였다.
//
// 구독에는 '광고 없이'가 들어 있다. 구독 중인 사람이 이것을 또 사면
// 돈만 버리므로, 그때는 누를 수 없게 두고 들어 있다고 말해 준다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:parrokit/core/shared/utils/remote_call_timeout.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import '../widgets/nav_tile.dart';

const String adsRemovalTitle = '광고 제거';

/// 광고 제거 화면이 붙어 있는 offering. RevenueCat 대시보드와 같아야 한다.
const String adsRemovalOfferingId = 'parrokit_ads_removed';

/// 아직 못 산 사람에게 보여 주는 한 줄.
const String adsRemovalBuySubtitle = '한 번 사면 쇼츠 광고가 사라져요.';

/// 이미 산 사람.
const String adsRemovalOwnedSubtitle = '광고를 지웠어요.';

/// 구독 중인 사람. 또 살 까닭이 없다.
const String adsRemovalInSubscriptionSubtitle = '구독에 들어 있어요.';

/// 살 수 없을 때.
const String adsRemovalNotReadyToast = '지금은 광고 제거를 살 수 없어요. 잠시 뒤 다시 해 주세요.';

/// 줄에 적을 말. 상태 셋을 한 곳에서 고른다.
String adsRemovalSubtitle({required bool subscribed, required bool owned}) {
  if (subscribed) return adsRemovalInSubscriptionSubtitle;
  if (owned) return adsRemovalOwnedSubtitle;
  return adsRemovalBuySubtitle;
}

/// 줄 오른쪽에 적을 상태. 구독 줄이 단계 이름('무료'·'라이트'·'프로')을
/// 적는 것과 같은 꼴로 맞춘다(5차 463).
String adsRemovalStateLabel({required bool subscribed, required bool owned}) {
  if (subscribed) return '구독 포함';
  return owned ? '켜짐' : '꺼짐';
}

/// 광고 제거 화면을 연다. 어느 화면을 띄울지 꼭 짚어 준다(5차 461에서
/// 구독을 눌렀더니 광고 제거 화면이 뜬 것과 반대 방향의 같은 실수를 막는다).
Future<void> showAdsRemovalPaywall(BuildContext context) async {
  try {
    final offerings = await Purchases.getOfferings().timeout(shortCallTimeout);
    final offering = offerings.all[adsRemovalOfferingId];
    if (offering == null) {
      showToast(adsRemovalNotReadyToast);
      return;
    }
    await RevenueCatUI.presentPaywall(offering: offering);
  } catch (_) {
    showToast(adsRemovalNotReadyToast);
  }
}

class AdsRemovalSection extends StatelessWidget {
  const AdsRemovalSection({super.key, this.onBuy});

  /// 테스트에서 실제 결제 화면 대신 쓸 것.
  final Future<void> Function(BuildContext context)? onBuy;

  @override
  Widget build(BuildContext context) {
    final subscribed = context.watch<SubscriptionProvider>().isSubscribed;
    final owned = context.watch<IapProvider>().isPremium;
    final blocked = subscribed || owned;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: NavTile(
        key: const ValueKey('ads-removal-row'),
        icon: Icons.block_rounded,
        title: adsRemovalTitle,
        subtitle: adsRemovalSubtitle(subscribed: subscribed, owned: owned),
        // 구독 줄과 같은 꼴: 오른쪽에 지금 상태를 글로 적는다.
        trailing: Text(
          adsRemovalStateLabel(subscribed: subscribed, owned: owned),
          key: const ValueKey('ads-removal-state'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        onTap: blocked ? null : () => (onBuy ?? showAdsRemovalPaywall)(context),
      ),
    );
  }
}
