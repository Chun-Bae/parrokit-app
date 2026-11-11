import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/settings/more/data/coin_package.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/coin_package_card.dart';

/// 코인 결제 섹션. RevenueCat Consumable IAP 연동.
class CoinStoreSection extends StatefulWidget {
  const CoinStoreSection({super.key});

  @override
  State<CoinStoreSection> createState() => _CoinStoreSectionState();
}

class _CoinStoreSectionState extends State<CoinStoreSection> {
  /// 현재 결제 진행 중인 productId (null이면 결제 없음)
  String? _purchasing;

  Future<void> _onPackageSelected(CoinPackage pkg) async {
    if (_purchasing != null) return;

    setState(() => _purchasing = pkg.productId);

    try {
      final products = await Purchases.getProducts([pkg.productId]);
      if (products.isEmpty) {
        showToast('상품 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
        return;
      }

      await Purchases.purchase(PurchaseParams.storeProduct(products.first));

      // 예외 없이 완료되면 결제 성공
      if (mounted) {
        await context.read<UserProvider>().addCoins(pkg.totalCoins);
        showToast('${pkg.totalCoins}코인이 충전됐어요!');
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        showToast('결제에 실패했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _purchasing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '코인 충전',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '1,000원 단위로 결제하고, 각 결제마다 10% 보너스 코인이 추가로 지급돼요.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: CoinPackage.packages
              .map(
                (pkg) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: CoinPackageCard(
                    package: pkg,
                    isLoading: _purchasing == pkg.productId,
                    onTap: _purchasing == null
                        ? () => _onPackageSelected(pkg)
                        : null,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
