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

/// '그림 + 쓴 횟수 / 한도' 한 쌍(5차 558·560, 사용자 요청).
///
/// 문장 추가 앱바와 단어 추가 시트 머리가 같은 것을 쓴다. 전에는 한쪽은
/// '오늘 2/3회 +1', 다른 쪽은 그림과 '2/3'으로 갈려 있었다.
class AssistUsagePair extends StatelessWidget {
  const AssistUsagePair({
    super.key,
    required this.kind,
    required this.used,
    required this.limit,
    this.credits = 0,
  });

  final AssistKind kind;
  final int? used;
  final int? limit;

  /// 패롯으로 사 둔 몫. 하루치를 다 써도 이것이 남아 있으면 더 쓸 수
  /// 있으므로 '+N'으로 적고 빨갛게 칠하지 않는다(5차 559).
  final int credits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // 아직 모르면 자리만 비워 둔다. '—/—'는 고장으로 읽힌다.
    final label = used == null || limit == null
        ? '—'
        : credits > 0
            ? '$used/$limit +$credits'
            : '$used/$limit';
    final full = credits <= 0 &&
        used != null &&
        limit != null &&
        limit! > 0 &&
        used! >= limit!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AssistIcon(kind, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: full ? cs.error : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
