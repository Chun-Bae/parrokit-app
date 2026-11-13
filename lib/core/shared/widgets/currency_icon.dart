import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum Currency {
  /// 패롯: 광고·충전으로 얻고 앱 기능(자막 생성 등)에 쓴다. 초록 동전.
  parrot('assets/currency/parrot.svg', '패롯'),

  /// 크래커: 커뮤니티에서 주고받는다(질문 보상). 구멍 난 비스킷.
  cracker('assets/currency/cracker.svg', '크래커');

  const Currency(this.asset, this.label);
  final String asset;
  final String label;
}

/// 패롯·크래커 그림. 예전에는 곳마다 🦜·🍪 이모지나 반짝이·쿠키 머티리얼
/// 아이콘을 따로 써서 같은 재화가 화면마다 다르게 보였다(5차). 한 그림으로 맞춘다.
class CurrencyIcon extends StatelessWidget {
  const CurrencyIcon(this.currency, {super.key, this.size = 18});

  final Currency currency;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: currency.label,
        excludeSemantics: true,
        child: SvgPicture.asset(currency.asset, width: size, height: size),
      );
}

/// 그림 + 수. 예: [크래커] 30
class CurrencyAmount extends StatelessWidget {
  const CurrencyAmount(
    this.currency,
    this.amount, {
    super.key,
    this.style,
    this.iconSize,
    this.prefix = '',
  });

  final Currency currency;
  final int amount;
  final TextStyle? style;
  final double? iconSize;

  /// 그림 앞에 붙는 말. 예: '답하면 '
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final effective = style ?? DefaultTextStyle.of(context).style;
    final size = iconSize ?? (effective.fontSize ?? 14) * 1.2;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (prefix.isNotEmpty) Text(prefix, style: effective),
      CurrencyIcon(currency, size: size),
      const SizedBox(width: 4),
      Text('$amount', style: effective),
    ]);
  }
}
