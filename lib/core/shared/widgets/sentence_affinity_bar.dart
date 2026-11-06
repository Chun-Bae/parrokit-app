import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';

/// 단계별 뱃지(`assets/badges/affinity_N.svg`)와 같은 계열의 칩 배경색과 글자색.
(Color, Color) affinityChipColors(int level) {
  const palette = [
    (Color(0xFFCFD8DC), Color(0xFF455A64)),
    (Color(0xFFC5E8B7), Color(0xFF2E6F3C)),
    (Color(0xFFA8F0E6), Color(0xFF0B6B66)),
    (Color(0xFFB9C8FF), Color(0xFF2E32A8)),
    (Color(0xFFFFE7A0), Color(0xFF8A4B00)),
  ];
  return palette[(level - 1).clamp(0, palette.length - 1)];
}

/// 문장 친밀도 단계와 다음 단계까지 진행 막대. 상세 시트와 따라 말하기 화면에서 함께 쓴다.
/// [compact]면 안내 문구 없이 한 줄과 얇은 막대만 그린다.
class SentenceAffinityBar extends StatelessWidget {
  const SentenceAffinityBar({
    super.key,
    required this.affinity,
    this.loading = false,
    this.compact = false,
  });

  final SentenceAffinity affinity;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final remaining = affinity.isMax ? 0 : affinity.next! - affinity.points;
    final title = loading
        ? '친밀도'
        : compact
            ? 'Lv.${affinity.level} ${affinity.name}'
            : '친밀도 Lv.${affinity.level} · ${affinity.name}';
    final hint =
        affinity.isMax ? '최고 단계예요' : '다음 단계까지 $remaining점 · 들으면 1점, 따라 말하면 2점';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SvgPicture.asset(
              'assets/badges/affinity_${affinity.level.clamp(1, SentenceAffinity.maxLevel)}.svg',
              width: compact ? 20 : 28,
              height: compact ? 20 : 28),
          SizedBox(width: compact ? 6 : 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: compact ? 12 : 14)),
          if (compact && !loading) ...[
            const Spacer(),
            Text(affinity.isMax ? 'MAX' : '$remaining점 남음',
                style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ]),
        SizedBox(height: compact ? 6 : 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: loading ? 0 : affinity.progress),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: compact ? 5 : 6,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(hint,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
        ],
      ],
    );
  }
}
