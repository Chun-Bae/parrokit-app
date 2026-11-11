import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';

/// 게시판 칩 줄 높이. 가로 스크롤이라 바깥에서 높이를 정해 줘야 한다.
const double _boardChipHeight = 36;

class CommunityShellFiltersSection extends StatelessWidget {
  const CommunityShellFiltersSection({
    super.key,
    required this.tabIndex,
    required this.selectedBoardFilter,
    required this.selectedQuestionFilter,
    required this.selectedVoteFilter,
    required this.onBoardFilterSelected,
    required this.onQuestionFilterSelected,
    required this.onVoteFilterSelected,
  });

  final int tabIndex;
  final String selectedBoardFilter;
  final String selectedQuestionFilter;
  final String selectedVoteFilter;
  final ValueChanged<String> onBoardFilterSelected;
  final ValueChanged<String> onQuestionFilterSelected;
  final ValueChanged<String> onVoteFilterSelected;

  @override
  Widget build(BuildContext context) {
    if (tabIndex == 0) {
      // 가로 스크롤 목록이라 높이를 정해 줘야 한다. 세그먼트는 내용에 맞춰 늘어난다.
      return SizedBox(
        height: _boardChipHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: CommunityFilters.board.length,
          itemBuilder: (context, index) {
            final filter = CommunityFilters.board[index];
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _BoardChip(
                label: filter,
                isSelected: selectedBoardFilter == filter,
                onTap: () => onBoardFilterSelected(filter),
              ),
            );
          },
        ),
      );
    }

    if (tabIndex == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppSegmentedTabs(
          selectedIndex: CommunityFilters.question
              .indexOf(selectedQuestionFilter)
              .clamp(0, CommunityFilters.question.length - 1),
          onChanged: (index) =>
              onQuestionFilterSelected(CommunityFilters.question[index]),
          segments: [
            for (final filter in CommunityFilters.question)
              AppSegment(label: filter),
          ],
        ),
      );
    }

    // '랜덤 보기'는 예전 이름이라 목록의 첫 항목으로 맞춰 읽는다.
    final voteFilter = selectedVoteFilter == '랜덤 보기'
        ? CommunityFilters.vote[0]
        : selectedVoteFilter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppSegmentedTabs(
        selectedIndex: CommunityFilters.vote
            .indexOf(voteFilter)
            .clamp(0, CommunityFilters.vote.length - 1),
        onChanged: (index) =>
            onVoteFilterSelected(CommunityFilters.vote[index]),
        segments: [
          for (var i = 0; i < CommunityFilters.vote.length; i++)
            AppSegment(label: CommunityFilters.vote[i], icon: _voteIcon(i)),
        ],
      ),
    );
  }

  static IconData _voteIcon(int index) => switch (index) {
        0 => Icons.style_rounded,
        1 => Icons.menu,
        2 => Icons.how_to_vote_rounded,
        _ => Icons.timer_off_rounded,
      };
}

class _BoardChip extends StatelessWidget {
  const _BoardChip(
      {required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDropdown = label == '최신';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.texts.bodyMedium.copyWith(
                  color: isSelected ? cs.onPrimary : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
            ),
            if (isDropdown) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
                  color: isSelected ? cs.onPrimary : cs.onSurface, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
