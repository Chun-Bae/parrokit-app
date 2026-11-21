import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// AI가 만들어 주는 두 가지(5차 544, 사용자 요청).
///
/// 패롯·크래커처럼 그림을 하나로 맞춘다. 전에는 두 한도가 글자로만 적혀
/// 있어서, 재화 줄 바로 아래에 붙여 두면 어느 쪽이 무엇인지 한눈에
/// 들어오지 않았다.
enum AssistKind {
  /// 뜻·발음 채우기. 말풍선. 파랑.
  meaning('assets/icons/assist_meaning.svg', '뜻·발음'),

  /// 예문 생성. 줄이 적힌 종이. 보라.
  example('assets/icons/assist_example.svg', '예문');

  const AssistKind(this.asset, this.label);
  final String asset;
  final String label;
}

/// 뜻·발음과 예문 그림. [CurrencyIcon]과 같은 결로 쓴다.
class AssistIcon extends StatelessWidget {
  const AssistIcon(this.kind, {super.key, this.size = 18});

  final AssistKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: kind.label,
        excludeSemantics: true,
        child: SvgPicture.asset(kind.asset, width: size, height: size),
      );
}
