import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';

/// 게시판 칩 줄 높이. 가로 스크롤이라 바깥에서 높이를 정해 줘야 한다.
///
/// 44로 둔다. 전에는 36이어서 손가락으로 누를 영역이 권장 최소치(44pt)보다
/// 작았다. SizedBox가 ListView를 가두니 칩 안에서 영역을 더 줄 수도 없었다.
/// 질문·투표 탭의 세그먼트 컨트롤도 44를 넘기므로 세 탭 높이가 맞는다.
const double _boardChipHeight = 44;

class CommunityShellFiltersSection extends StatelessWidget {
  const CommunityShellFiltersSection({
    super.key,
    required this.tabIndex,
    required this.selectedBoardFilter,
    required this.selectedQuestionStatus,
    required this.selectedQuestionSort,
    required this.selectedVoteFilter,
    required this.onBoardFilterSelected,
    required this.onQuestionStatusSelected,
    required this.onQuestionSortSelected,
    required this.onVoteFilterSelected,
  });

  final int tabIndex;
  final String selectedBoardFilter;
  final String selectedQuestionStatus;
  final String selectedQuestionSort;
  final String selectedVoteFilter;
  final ValueChanged<String> onBoardFilterSelected;
  final ValueChanged<String> onQuestionStatusSelected;
  final ValueChanged<String> onQuestionSortSelected;
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
      // 거르기와 정렬을 한 줄에 같이 두되 따로 고른다. 전에는 다섯 칸을
      // 한 세그먼트에 넣어 '답변 대기'를 보면서 '공감 순'으로 볼 수 없었다
      // (5차).
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: AppSegmentedTabs(
                selectedIndex: CommunityFilters.questionStatus
                    .indexOf(selectedQuestionStatus)
                    .clamp(0, CommunityFilters.questionStatus.length - 1),
                onChanged: (index) => onQuestionStatusSelected(
                    CommunityFilters.questionStatus[index]),
                segments: [
                  for (final filter in CommunityFilters.questionStatus)
                    AppSegment(label: filter),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _QuestionSortButton(
              selected: selectedQuestionSort,
              onSelected: onQuestionSortSelected,
            ),
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

/// 질문 정렬 고르기. 칸을 적게 쓰려고 세그먼트 대신 눌러서 고르는 메뉴로 둔다.
class _QuestionSortButton extends StatelessWidget {
  const _QuestionSortButton({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      key: const ValueKey('question-sort'),
      tooltip: '정렬',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final sort in CommunityFilters.questionSort)
          PopupMenuItem<String>(value: sort, child: Text(sort)),
      ],
      child: Container(
        height: _boardChipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected,
                style: context.texts.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 18, color: cs.onSurface),
          ],
        ),
      ),
    );
  }
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
