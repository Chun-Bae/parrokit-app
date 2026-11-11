// ============================================================================
// lib/features/dashboard/presentation/sections/continue_watching_section.dart
// ============================================================================
//
// [역할]
// 대시보드 이어보기 섹션.
// 최근 시청한 클립들을 가로 스크롤 리스트로 표시.
//
// [레이어]
// Presentation Layer > Sections
// DashboardScreen에서만 사용하는 화면 전용 섹션.
// ============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import '../widgets/section_header.dart';
import '../widgets/clip_thumbnail_card.dart';
import '../widgets/more_card.dart';

/// 대시보드 이어보기 섹션.
///
/// 최근 시청한 클립 6개를 가로 스크롤로 표시.
/// 비어있거나 6개 미만일 때 "더 보러가기" 카드 표시.
class ContinueWatchingSection extends StatelessWidget {
  // ─────────────────────────────────────────────────────────────────
  // 파라미터
  // ─────────────────────────────────────────────────────────────────

  /// 최근 시청 클립 리스트 (clipId, thumbnail, clipTitle, titleName)
  final List<(int, Uint8List?, String?, String?)> items;

  /// 클립 탭 콜백
  final void Function(int clipId) onTapItem;

  /// "모두 보기" 탭 콜백
  final VoidCallback onTapMore;

  /// 라이브러리 이동 콜백 (더 보러가기)
  final VoidCallback onTapLibrary;

  const ContinueWatchingSection({
    super.key,
    required this.items,
    required this.onTapItem,
    required this.onTapMore,
    required this.onTapLibrary,
  });

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg =
        isDark ? context.tokens.surfaceContainer : context.tokens.surface;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textPrimary = context.tokens.textPrimary;
    final textSecondary = context.tokens.textSecondary;

    final showGuide = items.isEmpty || items.length < 6;
    final itemCount = items.isEmpty ? 1 : items.length + (showGuide ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: SectionHeader(
            title: '이어보기',
            subtitle: '최근에 보던 클립',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            trailing: TextButton(
              onPressed: onTapMore,
              child: const Text('모두 보기'),
            ),
          ),
        ),

        // 클립 리스트
        SizedBox(
          height: 164,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              // 안내 카드 (비어있거나 끝에 표시)
              if (items.isEmpty || (i == items.length && showGuide)) {
                return MoreCard(
                  subtle: subtle,
                  textSecondary: textSecondary,
                  onTap: onTapLibrary,
                  isEmpty: items.isEmpty,
                );
              }

              // 클립 썸네일 카드
              final (clipId, imageBytes, clipTitle, titleName) = items[i];
              return ClipThumbnailCard(
                clipId: clipId,
                imageBytes: imageBytes,
                clipTitle: clipTitle ?? '무제',
                titleName: titleName,
                cardBg: cardBg,
                subtle: subtle,
                onTap: () => onTapItem(clipId),
              );
            },
          ),
        ),
      ],
    );
  }
}
