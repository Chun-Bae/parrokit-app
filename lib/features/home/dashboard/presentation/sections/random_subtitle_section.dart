// ============================================================================
// lib/features/dashboard/presentation/sections/random_subtitle_section.dart
// ============================================================================
//
// [역할]
// 대시보드 랜덤 자막 섹션.
// 무작위로 선택한 자막 세그먼트들을 리스트로 표시.
//
// [레이어]
// Presentation Layer > Sections
// DashboardScreen에서만 사용하는 화면 전용 섹션.
// Sliver 위젯을 반환하여 CustomScrollView에서 사용.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import '../widgets/section_header.dart';
import '../widgets/subtitle_tile.dart';
import '../widgets/empty_card.dart';

/// 대시보드 랜덤 자막 섹션.
///
/// [CustomScrollView]에서 사용하기 위해 Sliver 반환.
/// 로딩, 빈 상태, 데이터 상태를 처리.
class RandomSubtitleSection extends StatelessWidget {
  // ─────────────────────────────────────────────────────────────────
  // 파라미터
  // ─────────────────────────────────────────────────────────────────

  /// 무작위 자막 세그먼트 리스트
  final List<Segment> segments;

  /// 로딩 상태
  final bool loading;

  const RandomSubtitleSection({
    super.key,
    required this.segments,
    required this.loading,
  });

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardBg =
        isDark ? context.tokens.surfaceContainer : context.tokens.surface;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textPrimary = context.tokens.textPrimary;
    final textSecondary = context.tokens.textSecondary;

    return SliverMainAxisGroup(
      slivers: [
        // 섹션 헤더
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: SectionHeader(
              title: '랜덤으로 자막 보기',
              subtitle:
                  loading ? '불러오는 중...' : '${segments.length}개를 무작위로 골라왔어요',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ),
        ),

        // 로딩 스켈레톤
        if (loading)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SubtitleTile.skeleton(cardBg: cardBg, subtle: subtle),
              ),
              childCount: segments.isEmpty ? 3 : segments.length,
            ),
          )
        // 빈 상태
        else if (segments.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: EmptyCard(
                noun: '자막',
                subtle: subtle,
                textSecondary: textSecondary,
              ),
            ),
          )
        // 데이터 리스트
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final seg = segments[i];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: SubtitleTile(
                    original: seg.original,
                    pron: seg.pron,
                    trans: seg.trans,
                    cardBg: cardBg,
                    subtle: subtle,
                    textPrimary: textPrimary,
                    primaryColor: cs.primary,
                    tertiaryColor: cs.tertiary,
                    onTap: () => context.pushNamed(
                      AppRoutes.clipsPlay,
                      queryParameters: {'clipId': seg.clipId.toString()},
                    ),
                  ),
                );
              },
              childCount: segments.length,
            ),
          ),
      ],
    );
  }
}
