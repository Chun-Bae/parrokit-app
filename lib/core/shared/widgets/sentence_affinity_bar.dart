import 'package:flutter/material.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';

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
          Icon(Icons.favorite_rounded,
              size: compact ? 14 : 16, color: colors.primary),
          const SizedBox(width: 6),
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
