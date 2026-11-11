// ============================================================================
// lib/features/_content/shorts/presentation/widgets/shorts_badge.dart
// ============================================================================
//
// [역할]
// 쇼츠 화면 하단 설명 영역에 표시되는 태그(Tag) 배지.
//
// [기능]
// - 둥근 모서리의 반투명 배경
// - 아이콘과 텍스트 라벨 표시
//
// [레이어]
// Presentation Layer > Widgets
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// [역할]
/// 쇼츠 화면에서 클립의 태그 정보를 아이콘과 함께 표시하는 배지 위젯.
class ShortsBadge extends StatelessWidget {
  const ShortsBadge({required this.label, required this.icon, super.key});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // ✅ 다크/라이트 무시하고 고정 색상 사용
    const Color fixedColor = Colors.white; // 필요시 Colors.white 등으로 변경

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: fixedColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: fixedColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fixedColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fixedColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
