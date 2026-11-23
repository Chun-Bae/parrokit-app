import 'package:parrokit/features/settings/more/presentation/sections/coin_purchase_text.dart';
// ============================================================================
// lib/features/more/presentation/sections/payment_section.dart
// ============================================================================
//
// [역할]
// 결제 섹션 위젯 (광고 제거 + 코인 충전 + 구매 내역).
// RevenueCat Paywall / Customer Center 연동.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/settings/more/data/coin_package.dart';
import '../widgets/card_container.dart';
import '../widgets/nav_tile.dart';
import '../widgets/section_title.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 결제 섹션 (광고 제거 + 코인 충전 + 구매 내역).
class PaymentSection extends StatelessWidget {
  const PaymentSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<IapProvider>().isPremium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('결제'),
        const SizedBox(height: 10),
        CardContainer(
          child: Column(
            children: [
              // 광고 제거
              NavTile(
                icon: Icons.block_rounded,
                title: '광고 제거',
                subtitle:
                    isPremium ? '쇼츠 광고가 비활성화되어 있어요' : '한 번 구매로 모든 광고를 없애요',
                showArrow: !isPremium,
                trailing: isPremium ? _buildActiveChip(context) : null,
                onTap: isPremium ? null : () => _presentPaywall(context),
              ),

              // 코인 충전
              const Divider(height: 1, indent: 16, endIndent: 16),
              NavTile(
                icon: Icons.toll_rounded,
                title: '코인 충전',
                subtitle: '결제마다 10% 보너스 코인 지급',
                onTap: () => _openCoinPaywall(context),
              ),

              // 구매 내역
              const Divider(height: 1, indent: 16, endIndent: 16),
              NavTile(
                icon: Icons.receipt_long_rounded,
                title: '구매 내역',
                onTap: () => RevenueCatUI.presentCustomerCenter(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveChip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '구매 완료',
        style: context.texts.bodySmall.copyWith(color: cs.onPrimaryContainer),
      ),
    );
  }

  Future<void> _presentPaywall(BuildContext context) async {
    await RevenueCatUI.presentPaywallIfNeeded(IapProvider.entitlementId);
  }

  Future<void> _openCoinPaywall(BuildContext context) async {
    Offering? offering;
    try {
      final offerings = await Purchases.getOfferings();
      offering = offerings.getOffering('parrokit_coins');
    } catch (_) {}

    if (offering == null) {
      showToast(productLoadFailedMessage);
      return;
    }
    if (!context.mounted) return;

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CoinPaywallPage(
          offering: offering!,
          userProvider: context.read<UserProvider>(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 코인 페이월 페이지 (PaywallView + onPurchaseCompleted 콜백)
// ─────────────────────────────────────────────────────────────────────────────

class _CoinPaywallPage extends StatefulWidget {
  final Offering offering;
  final UserProvider userProvider;

  const _CoinPaywallPage({
    required this.offering,
    required this.userProvider,
  });

  @override
  State<_CoinPaywallPage> createState() => _CoinPaywallPageState();
}

class _CoinPaywallPageState extends State<_CoinPaywallPage> {
  @override
  Widget build(BuildContext context) {
    return PaywallView(
      offering: widget.offering,
      displayCloseButton: true,
      onPurchaseCompleted: (_, storeTransaction) {
        // 구매 즉시 코인 지급 + 토스트 (onDismiss 의존 X)
        final productId = storeTransaction.productIdentifier;
        final matched =
            CoinPackage.packages.where((p) => p.productId == productId);

        // 못 찾으면 첫 상품 기준으로 준다. 지금 동작 그대로다. 다만 조용히
        // 넘어가면 안 된다 — RevenueCat에만 상품을 추가하고 앱의
        // CoinPackage.packages에 안 넣으면, 사용자가 낸 돈과 받는 코인이
        // 어긋난 채로 아무 흔적이 안 남는다.
        if (matched.isEmpty) {
          AppLogger.e('[Paywall] 앱에 없는 상품이 결제됐다 productId=$productId. '
              'CoinPackage.packages 첫 항목 기준으로 지급한다.');
        }
        final pkg =
            matched.isNotEmpty ? matched.first : CoinPackage.packages.first;

        // 지급은 **서버가 한다**(5차 568). 앱이 직접 넣던 때는 영수증을
        // 확인하는 곳이 없어서, 결제 없이 자기 문서의 parrots를 올려도
        // 그대로 패롯이 됐다. 이제 RevenueCat 웹훅을 받은
        // onSubscriptionEvent가 넣고, 잔액은 사용자 문서 구독으로 곧 바뀐다.
        showToast(coinsComingMessage(pkg.totalCoins));
      },
      onDismiss: () {
        Navigator.of(context, rootNavigator: true).pop();
      },
      onPurchaseError: (_) {
        showToast(paymentFailedMessage);
      },
    );
  }
}
