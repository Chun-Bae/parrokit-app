// 패롯이 모자랄 때 뜨는 안내(5차 4단계).
//
// 전에는 토스트 한 줄('패롯이 부족합니다. (필요 5 / 보유 4)')뿐이라 무엇을
// 할 수 있는지 알 수 없었다. 할 수 있는 일을 버튼으로 둔다.
// 패롯 충전은 스토어 상품이 아직 없어서 넣지 않는다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/features/settings/more/presentation/sections/ad_reward_button.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

/// 제목과 본문. 무엇에 얼마가 필요한지 그대로 적는다.
const String notEnoughParrotsTitle = '패롯이 모자라요';

String notEnoughParrotsBody({required int needed, required int have}) =>
    '이번 작업에 $needed개가 필요한데 $have개가 있어요.';

/// 화면을 들고 있지 않은 곳(Provider)에서 부른다. 띄울 화면이 없으면
/// 예전처럼 토스트 한 줄로 알린다.
Future<void> showNotEnoughParrots({required int needed, required int have}) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) {
    showToast('$notEnoughParrotsTitle ${notEnoughParrotsBody(
      needed: needed,
      have: have,
    )}');
    return Future<void>.value();
  }
  return showNotEnoughParrotsSheet(context, needed: needed, have: have);
}

Future<void> showNotEnoughParrotsSheet(
  BuildContext context, {
  required int needed,
  required int have,
  PaywallPresenter? presenter,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => NotEnoughParrotsSheet(
      needed: needed,
      have: have,
      presenter: presenter,
    ),
  );
}

class NotEnoughParrotsSheet extends StatelessWidget {
  const NotEnoughParrotsSheet({
    super.key,
    required this.needed,
    required this.have,
    this.presenter,
  });

  final int needed;
  final int have;

  /// 테스트에서 가짜를 넣기 위한 자리.
  final PaywallPresenter? presenter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tier = context.watch<SubscriptionProvider>().tier;
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(notEnoughParrotsTitle, style: context.texts.titleLarge),
            const SizedBox(height: 6),
            Text(
              notEnoughParrotsBody(needed: needed, have: have),
              key: const ValueKey('not-enough-body'),
              style: context.texts.bodyReading
                  .copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            AdRewardButton(style: buttonStyle),
            if (tier == SubscriptionTier.free) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                key: const ValueKey('not-enough-subscribe'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  Navigator.of(context).pop();
                  (presenter ?? resolvePaywallPresenter()).show(context);
                },
                child: const Text(subscriptionOpenButtonLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
