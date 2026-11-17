// 더보기 '상품' 칸의 '패롯 충전' 줄(5차 466).
//
// 464에서 지갑 카드에 '충전' 버튼을 넣었는데, 파는 것을 모아 둔 '상품'
// 칸에는 패롯만 빠져 있었다. 구독과 광고 제거는 줄로 있는데 패롯만
// 지갑 카드 안 작은 버튼이라, 상품 칸만 보면 살 수 있는 줄 몰랐다.
//
// 지갑 카드의 '충전' 버튼은 그대로 둔다. 패롯 수를 보고 바로 누르는
// 자리라 그쪽이 더 가깝다. 둘 다 같은 화면을 연다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/settings/more/presentation/sections/store_paywall.dart';
import 'package:parrokit/features/settings/shared/store_badges.dart';
import '../widgets/nav_tile.dart';

final NumberFormat _count = NumberFormat.decimalPattern();

const String parrotTopupTitle = '패롯 충전';
const String parrotTopupSubtitle = '사서 바로 채워요. 광고를 봐도 받아요.';

class ParrotTopupSection extends StatelessWidget {
  const ParrotTopupSection({super.key, this.onBuy});

  /// 테스트에서 실제 결제 화면 대신 쓸 것.
  final Future<void> Function(BuildContext context)? onBuy;

  @override
  Widget build(BuildContext context) {
    // 지갑 카드와 같은 값을 쓴다. 구독으로 받은 패롯까지 합친,
    // 지금 쓸 수 있는 양이다.
    final user = context.watch<UserProvider>().currentUser;
    final parrots = user?.spendableParrots ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: NavTile(
        key: const ValueKey('parrot-topup-row'),
        icon: parrotTopupBadge.icon,
        iconAsset: parrotTopupBadge.asset,
        iconGradient: parrotTopupBadge.colors,
        title: parrotTopupTitle,
        subtitle: parrotTopupSubtitle,
        // 구독·광고 제거 줄과 같은 꼴: 오른쪽에 지금 상태를 글로 적는다.
        trailing: Text(
          '${_count.format(parrots)}개',
          key: const ValueKey('parrot-topup-balance'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        onTap: () => (onBuy ?? showParrotStorePaywall)(context),
      ),
    );
  }
}
