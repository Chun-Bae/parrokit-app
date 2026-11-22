import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';

/// AI가 만들어 주는 두 가지(5차 544, 사용자 요청).
///
/// 패롯·크래커처럼 그림을 하나로 맞춘다. 전에는 두 한도가 글자로만 적혀
/// 있어서, 재화 줄 바로 아래에 붙여 두면 어느 쪽이 무엇인지 한눈에
/// 들어오지 않았다.
enum AssistKind {
  /// 뜻·발음·원문 생성. 말풍선. 파랑.
  ///
  /// 읽어 주는 말도 단추와 맞춘다(5차 562). 단어 고치기 시트만 낱말이
  /// 고정이라 '뜻·발음'이지만, 그 한 자리 때문에 가르지 않는다.
  meaning('assets/icons/assist_meaning.svg', fillBasicsSubject),

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

  /// 패롯으로 사 둔 몫. 좁은 자리에서는 '+N'을 따로 적지 않고 분모에
  /// 합친다(5차 561, 사용자 요청) - 한도 3에 사 둔 몫 1이면 '3/4'다.
  /// 쪼개 보여 주는 것은 더보기 카드가 맡는다.
  final int credits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // 아직 모르면 자리만 비워 둔다. '—/—'는 고장으로 읽힌다.
    // 오늘 쓸 수 있는 전부. 사 둔 몫은 날이 바뀌어도 남으므로 하루
    // 한도와 성격이 다르지만, 여기서는 '몇 번 더 되는지'만 보면 된다.
    final total = limit == null ? null : limit! + (credits > 0 ? credits : 0);
    final label = used == null || total == null ? '—' : '$used/$total';
    final full = used != null && total != null && total > 0 && used! >= total;
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
