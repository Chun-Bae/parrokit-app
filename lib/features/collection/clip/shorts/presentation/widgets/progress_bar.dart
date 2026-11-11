// ============================================================================
// lib/features/_content/shorts/presentation/widgets/progress_bar.dart
// ============================================================================
//
// [역할]
// 쇼츠 화면 상단의 스토리 스타일 진행 표시줄.
//
// [기능]
// - 전체 클립 개수([total])만큼 세그먼트 표시
// - 현재 인덱스([index]) 강조 표시
//
// [레이어]
// Presentation Layer > Widgets
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// [역할]
/// 현재 재생 중인 클립의 순서를 상단에 표시하는 위젯.
/// 인스타그램 스토리나 릴스와 유사한 형태의 UI를 제공합니다.
class ProgressBar extends StatelessWidget {
  const ProgressBar({required this.index, required this.total, super.key});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(total, (i) {
        final active = i == index;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : AppSpacing.xs),
            decoration: BoxDecoration(
              color: active
                  ? scheme.onSecondary
                  : scheme.onSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.track),
            ),
          ),
        );
      }),
    );
  }
}
