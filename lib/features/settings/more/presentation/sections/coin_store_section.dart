import 'package:parrokit/features/settings/more/presentation/sections/coin_purchase_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
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
        showToast(productLoadFailedMessage);
        return;
      }

      await Purchases.purchase(PurchaseParams.storeProduct(products.first));

      // 예외 없이 완료되면 결제 성공.
      //
      // 지급은 **서버가 한다**(5차 568). 앱이 직접 넣던 때는 영수증을
      // 확인하는 곳이 없어서, 결제 없이 자기 문서의 parrots를 올려도
      // 그대로 패롯이 됐다. 이제 RevenueCat 웹훅을 받은
      // onSubscriptionEvent가 넣고, 잔액은 사용자 문서 구독으로 곧 바뀐다.
      //
      // 화면이 사라져도 상관없다. 지급이 앱 수명과 끊겨 있어서, 결제 시트를
      // 띄운 사이에 앱을 내려도 돈만 받고 끝나는 일이 없다.
      if (mounted) {
        showToast(coinsComingMessage(pkg.totalCoins));
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        showToast(paymentFailedMessage);
      }
    } catch (e) {
      // 결제 흐름에서 넘어진 경우다. 지급은 서버가 하므로 여기서 실패해도
      // 결제가 끝났다면 패롯은 웹훅으로 들어온다.
      AppLogger.e('[CoinStore] 결제 흐름 실패 productId=${pkg.productId}', error: e);
      showToast(paymentFailedMessage);
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
