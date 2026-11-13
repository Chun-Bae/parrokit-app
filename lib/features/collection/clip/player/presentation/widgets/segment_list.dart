import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import '../clip_time_format.dart';

class SegmentList extends StatelessWidget {
  const SegmentList({
    super.key,
    required this.segments,
    required this.currentIndex,
    required this.onTapItem,
  });

  final List<Segment> segments;
  final int currentIndex;
  final ValueChanged<int> onTapItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: segments.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
      itemBuilder: (ctx, i) {
        final seg = segments[i];
        final active = i == currentIndex;

        final chip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text('#${i + 1}  ${segmentRangeLabel(seg.startMs, seg.endMs)}',
              style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.7),
                  )),
        );

        return ListTile(
          dense: true,
          onTap: () => onTapItem(i),
          title: Row(children: [chip]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 원문·발음·해석이 같은 크기라 어느 줄이 무엇인지 헷갈렸다(5차).
                // 원문은 크게, 발음은 작고 흐리게, 해석은 보통 크기로. 빈 줄은 뺀다.
                Text(seg.original,
                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                if (seg.pron.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(seg.pron,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          )),
                ],
                if (seg.trans.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(seg.trans,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.85),
                          )),
                ],
              ],
            ),
          ),
          trailing: active
              ? Icon(Icons.play_arrow_rounded, color: cs.primary)
              : const Icon(Icons.play_arrow_rounded, color: Colors.transparent),
        );
      },
    );
  }
}
