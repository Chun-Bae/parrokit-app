import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
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

    // 결제가 끝난 뒤에 context를 읽으면 안 되고, 화면이 사라졌다고 코인을
    // 안 줘서도 안 된다. 그래서 Provider는 결제를 시작하기 전에 잡아 둔다.
    final userProvider = context.read<UserProvider>();

    setState(() => _purchasing = pkg.productId);

    try {
      final products = await Purchases.getProducts([pkg.productId]);
      if (products.isEmpty) {
        showToast('상품 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
        return;
      }

      await Purchases.purchase(PurchaseParams.storeProduct(products.first));

      // 예외 없이 완료되면 결제 성공.
      //
      // 여기에 `if (mounted)`가 걸려 있었다. 결제 시트를 띄운 사이에 화면이
      // 사라지면(앱을 내렸다 올리거나 다른 탭으로 갔거나) 결제는 됐는데
      // 코인을 안 주고 끝났다. 돈만 받는 셈이다. 지급은 화면 수명과 무관하게
      // 한다. mounted는 토스트에만 건다.
      await userProvider.addCoins(pkg.totalCoins);
      if (mounted) {
        showToast('${pkg.totalCoins}코인이 충전됐어요!');
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        showToast('결제에 실패했어요. 다시 시도해 주세요.');
      }
    } catch (e) {
      // 결제 자체는 끝났는데 지급에서 넘어진 경우다. 조용히 사라지면
      // 사용자는 돈을 내고 아무것도 못 받은 채 이유도 모른다.
      AppLogger.e('[CoinStore] 코인 지급 실패 productId=${pkg.productId}',
          error: e);
      showToast('결제는 됐지만 코인 지급에 실패했어요. 앱을 다시 켜 보고, 그래도 안 되면 문의해 주세요.');
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
