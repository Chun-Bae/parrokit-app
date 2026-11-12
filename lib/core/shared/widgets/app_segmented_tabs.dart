import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 세그먼트 컨트롤 한 칸.
class AppSegment {
  const AppSegment({required this.label, this.icon, this.locked = false});

  final String label;

  /// 없으면 글자만 보여준다.
  final IconData? icon;

  /// 아직 쓸 수 없는 칸. 옅게 그리고 라벨 옆에 자물쇠를 붙인다.
  /// 눌리기는 하므로 눌렀을 때 무엇을 보여줄지는 [AppSegmentedTabs.onChanged]
  /// 쪽에서 정한다.
  final bool locked;
}

/// 앱 전역 세그먼트 컨트롤.
///
/// 옅은 트랙 위에 선택된 칸만 표면색 카드로 떠오르는 iOS 방식이다.
/// 보관함 상단 탭, 보관함 안의 모드 전환, 라이브러리의 보기 전환과
/// 저장위치 전환이 모두 이 위젯을 쓴다.
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.stacked = false,
    this.position,
  });

  final List<AppSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// true면 아이콘을 라벨 위에 쌓는다. 보관함 상단 탭처럼 칸이 높을 때 쓴다.
  final bool stacked;

  /// 선택 표시의 연속 위치(0 ~ 칸 수-1). TabBarView를 손가락으로 끌 때
  /// 컨트롤러의 animation.value를 넘기면 표시가 손가락을 따라 움직인다.
  /// 비우면 [selectedIndex]로 미끄러지듯 옮겨 간다.
  final double? position;

  static const _slide = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final count = segments.length;
    // 전에는 칸마다 배경을 따로 켜고 꺼서, 바뀔 때 옛 칸이 사라지고 새 칸이
    // 나타나는 깜빡임으로 보였다. 이제 표시 하나가 칸 사이를 미끄러진다.
    final target = (position ?? selectedIndex.toDouble())
        .clamp(0.0, (count - 1).toDouble());
    final follow = position != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: tokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / count;
          final indicator = DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          );
          return Stack(
            children: [
              if (follow)
                Positioned(
                  left: target * width,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: indicator,
                )
              else
                AnimatedPositioned(
                  duration: _slide,
                  curve: Curves.easeOutCubic,
                  left: target * width,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: indicator,
                ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: _Segment(
                        segment: segments[i],
                        selected: i == selectedIndex,
                        stacked: stacked,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.stacked,
    required this.onTap,
  });

  final AppSegment segment;
  final bool selected;
  final bool stacked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final foreground = segment.locked
        ? tokens.textDisabled
        : (selected ? tokens.textPrimary : tokens.textSecondary);
    final label = Text(
      segment.label,
      textAlign: TextAlign.center,
      style: context.texts.bodyMedium
          .copyWith(color: foreground, fontWeight: FontWeight.w800),
    );
    final icon = segment.icon == null
        ? null
        : Icon(segment.icon, size: 18, color: foreground);
    final lock = segment.locked
        ? Icon(Icons.lock_rounded, size: 14, color: foreground)
        : null;

    // 배경은 AppSegmentedTabs의 미끄러지는 표시가 그린다.
    return SizedBox(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            // 세로 10은 글자 높이를 더해 44pt 터치 영역을 넘긴다.
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
            child: stacked && icon != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(height: AppSpacing.xs),
                      label,
                      if (lock != null) ...[
                        const SizedBox(height: 2),
                        lock,
                      ],
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        icon,
                        const SizedBox(width: AppSpacing.xs + 2),
                      ],
                      Flexible(child: label),
                      if (lock != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        lock,
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
