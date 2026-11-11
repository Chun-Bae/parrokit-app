// ============================================================================
// lib/features/recent/presentation/widgets/recent_list_skeleton.dart
// ============================================================================
//
// [역할]
// 최근 본 클립 목록 로딩 스켈레톤.
// 쉬머 애니메이션으로 로딩 상태 표시.
//
// [레이어]
// Presentation Layer > Widgets
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';

/// 최근 본 클립 목록 로딩 스켈레톤.
class RecentListSkeleton extends StatelessWidget {
  const RecentListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest.withValues(alpha: .65);
    final hilite = cs.surface;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemBuilder: (_, __) => _ShimmerTile(base: base, hilite: hilite),
      separatorBuilder: (_, __) => Divider(
        height: 8,
        thickness: 0.5,
        color: cs.outlineVariant.withValues(alpha: .6),
      ),
      itemCount: 8,
    );
  }
}

/// 쉬머 타일.
class _ShimmerTile extends StatefulWidget {
  const _ShimmerTile({required this.base, required this.hilite});

  final Color base;
  final Color hilite;

  @override
  State<_ShimmerTile> createState() => _ShimmerTileState();
}

class _ShimmerTileState extends State<_ShimmerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _animation =
      Tween(begin: 0.0, end: 1.0).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = context.tokens.divider;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return Container(
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.1, 0.3, 0.5, 0.7, 0.9],
              colors: [
                widget.base,
                Color.lerp(
                  widget.base,
                  widget.hilite,
                  _animation.value * .6 + .2,
                )!,
                widget.base,
                Color.lerp(
                  widget.base,
                  widget.hilite,
                  _animation.value * .6 + .2,
                )!,
                widget.base,
              ],
            ),
          ),
        );
      },
    );
  }
}
