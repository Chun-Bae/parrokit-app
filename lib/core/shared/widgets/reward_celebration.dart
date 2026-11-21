// 크래커를 받았을 때 '짜잔' 하고 한 번 보여 주는 덮개(5차 509, 사용자 요청).
//
// 복습을 마치면 받은 크래커를 글 한 줄로만 적었다. 받은 것이 눈에 안 띄어서
// 뭘 받았는지 모르고 닫는 일이 많았다. 마친 그 순간에 가운데로 크게 띄운다.
//
// 애니메이션을 끈 기기(MediaQuery.disableAnimations)에서는 움직임 없이 바로
// 제 크기로 보여 준다.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/core/content/practice_reward.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/currency_icon.dart';

/// 덮개가 저절로 사라지기까지. 누르면 바로 닫힌다.
const Duration rewardCelebrationStay = Duration(seconds: 3);

/// 받은 크래커를 가운데에 띄운다. [crackers]가 0 이하면 아무것도 하지 않는다.
///
/// 시트 위에 띄워야 해서 rootNavigator를 쓰지 않는다. 띄운 화면이 사라지면
/// 함께 사라진다.
Future<void> showRewardCelebration(
  BuildContext context, {
  required int crackers,
}) {
  if (crackers <= 0) return Future.value();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (_) => _RewardCelebration(crackers: crackers),
  );
}

class _RewardCelebration extends StatefulWidget {
  const _RewardCelebration({required this.crackers});

  final int crackers;

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
                  const CurrencyIcon(Currency.cracker, size: 56),
                  const SizedBox(height: 12),
                  Text('짜잔!',
                      key: const ValueKey('reward-celebration-title'),
                      style: context.texts.titleLarge.copyWith(
                        color: Colors.white,
                        shadows: _celebrationShadows,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    practiceRewardEarned(widget.crackers),
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
