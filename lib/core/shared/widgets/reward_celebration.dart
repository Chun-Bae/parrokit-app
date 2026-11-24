// 무언가를 받았을 때 '짜잔' 하고 한 번 보여 주는 덮개(5차 509, 사용자 요청).
//
// 복습을 마치면 받은 크래커를 글 한 줄로만 적었다. 받은 것이 눈에 안 띄어서
// 뭘 받았는지 모르고 닫는 일이 많았다. 마친 그 순간에 가운데로 크게 띄운다.
//
// 광고를 보고 받는 패롯도 토스트 한 줄이라 같은 처지였다. 재화를 가려
// 받으므로 크래커와 패롯이 같은 꼴로 뜬다(5차 568, 사용자 요청).
//
// 애니메이션을 끈 기기(MediaQuery.disableAnimations)에서는 움직임 없이 바로
// 제 크기로 보여 준다.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/core/content/practice_reward.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/assist_icon.dart';
import 'package:parrokit/core/shared/widgets/currency_icon.dart';

/// 덮개가 저절로 사라지기까지. 누르면 바로 닫힌다.
const Duration rewardCelebrationStay = Duration(seconds: 3);

/// 받은 것을 가운데에 띄운다. [amount]가 0 이하면 아무것도 하지 않는다.
///
/// 시트 위에 띄워야 해서 rootNavigator를 쓰지 않는다. 띄운 화면이 사라지면
/// 함께 사라진다.
Future<void> showRewardCelebration(
  BuildContext context, {
  required int amount,
  Currency currency = Currency.cracker,
}) =>
    _celebrate(
      context,
      amount: amount,
      icon: CurrencyIcon(currency, size: _celebrationIconSize),
      text: rewardCelebrationAmount(currency, amount),
    );

/// 뜻·발음·원문과 예문 몫을 채웠을 때도 같은 덮개로 띄운다(5차, 사용자 요청).
///
/// 패롯·크래커와 달리 지갑에 쌓이는 재화는 아니지만, 사용자가 패롯을 내고
/// 받는 것은 같다. 전에는 글 한 줄이라 산 것이 눈에 안 띄었다. 그림만 그
/// 몫의 것([AssistKind])으로 바꾸고 꼴은 그대로 쓴다.
Future<void> showAssistCelebration(
  BuildContext context, {
  required int amount,
  required AssistKind kind,
}) =>
    _celebrate(
      context,
      amount: amount,
      icon: AssistIcon(kind, size: _celebrationIconSize),
      text: '${kind.label} +$amount',
    );

/// 덮개 가운데 그림 크기.
const double _celebrationIconSize = 56;

/// 서버가 넣어 줄 때까지 기다리는 덮개(5차, 사용자 요청).
///
/// 광고가 닫히고 잔액이 오르기까지 몇 초가 뜬다. 전에는 그 사이를 토스트
/// 한 줄('곧 받아요')로 때웠는데, 광고가 닫히는 어수선한 순간이라 묻혔고
/// 받은 건지 만 건지도 알 수 없었다. 같은 자리에 덮개를 띄워 두고, 들어오면
/// 그대로 '짜잔'으로 바꾼다.
///
/// [until]이 끝나면 스스로 닫히고 그 값을 돌려준다. 누르거나 뒤로 가도
/// 닫히지 않는다 - 기다리는 중에 닫히면 받은 것을 못 보여 준다.
Future<T> showRewardPending<T>(
  BuildContext context, {
  required Future<T> until,
  required Widget icon,
  required String text,
}) async {
  BuildContext? sheet;
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      sheet = dialogContext;
      return PopScope(
        canPop: false,
        child: _RewardPending(icon: icon, text: text),
      );
    },
  ));
  try {
    return await until;
  } finally {
    // 띄운 그 창만 닫는다. 그 사이에 사용자가 다른 화면을 열었어도
    // 엉뚱한 것을 닫지 않는다.
    final open = sheet;
    if (open != null && open.mounted) Navigator.of(open).pop();
  }
}

/// 기다리는 동안 보여 주는 속. '짜잔'과 자리·크기를 맞춰 둬서, 바뀔 때
/// 화면이 튀지 않는다.
class _RewardPending extends StatelessWidget {
  const _RewardPending({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        key: const ValueKey('reward-pending'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _celebrationIconSize,
                height: _celebrationIconSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(opacity: 0.45, child: icon),
                    const SizedBox(
                      width: _celebrationIconSize,
                      height: _celebrationIconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('받는 중',
                  key: const ValueKey('reward-pending-title'),
                  style: context.texts.titleLarge.copyWith(
                    color: Colors.white,
                    shadows: _celebrationShadows,
                  )),
              const SizedBox(height: 4),
              Text(
                text,
                key: const ValueKey('reward-pending-text'),
                style: context.texts.headlineSmall.copyWith(
                  color: Colors.white,
                  shadows: _celebrationShadows,
                ),
              ),
            ],
          ),
        ),
      );
}

Future<void> _celebrate(
  BuildContext context, {
  required int amount,
  required Widget icon,
  required String text,
}) {
  if (amount <= 0) return Future.value();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (_) => _RewardCelebration(icon: icon, text: text),
  );
}

/// 덮개 가운데에 적는 말. 크래커는 연습 보상과 같은 꼴을 쓴다.
String rewardCelebrationAmount(Currency currency, int amount) =>
    currency == Currency.cracker ?
        practiceRewardEarned(amount) :
        '${currency.label} +$amount';

class _RewardCelebration extends StatefulWidget {
  const _RewardCelebration({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  State<_RewardCelebration> createState() => _RewardCelebrationState();
}

/// 배경 없이 띄우므로 글자가 밝은 화면에 묻히지 않게 깔아 두는 그림자.
const List<Shadow> _celebrationShadows = [
  Shadow(color: Colors.black54, blurRadius: 12),
];

class _RewardCelebrationState extends State<_RewardCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Timer? closer;

  @override
  void initState() {
    super.initState();
    // 애니메이션을 끈 기기에서는 처음부터 다 자란 모습으로 둔다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.value = 1;
      } else {
        controller.forward();
      }
      closer = Timer(rewardCelebrationStay, () {
        if (mounted) Navigator.of(context).maybePop();
      });
    });
  }

  @override
  void dispose() {
    closer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: controller, curve: Curves.elasticOut);
    return GestureDetector(
      key: const ValueKey('reward-celebration'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1).animate(scale),
          child: FadeTransition(
            opacity: controller,
            // 흰 카드 없이 어두운 막 위에 바로 올린다(5차 515, 사용자 요청).
            // 배경이 사라졌으니 글자는 흰색으로 두고, 밝은 화면 위에서도
            // 읽히도록 그림자를 깐다.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.icon,
                  const SizedBox(height: 12),
                  Text('짜잔!',
                      key: const ValueKey('reward-celebration-title'),
                      style: context.texts.titleLarge.copyWith(
                        color: Colors.white,
                        shadows: _celebrationShadows,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    widget.text,
                    key: const ValueKey('reward-celebration-amount'),
                    style: context.texts.headlineSmall.copyWith(
                      color: Colors.white,
                      shadows: _celebrationShadows,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
