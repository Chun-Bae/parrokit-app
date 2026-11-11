import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

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
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: CommunityFilters.board.length,
        itemBuilder: (context, index) {
          final filter = CommunityFilters.board[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _BoardChip(
              label: filter,
              isSelected: selectedBoardFilter == filter,
              onTap: () => onBoardFilterSelected(filter),
            ),
          );
        },
      );
    }

    if (tabIndex == 1) {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: CommunityFilters.question.length,
        itemBuilder: (context, index) {
          final filter = CommunityFilters.question[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _QuestionTab(
              title: filter,
              isSelected: selectedQuestionFilter == filter,
              onTap: () => onQuestionFilterSelected(filter),
            ),
          );
        },
      );
    }

    return _VoteToggle(
      selectedVoteFilter: selectedVoteFilter,
      onVoteFilterSelected: onVoteFilterSelected,
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
          borderRadius: BorderRadius.circular(18),
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

class _QuestionTab extends StatelessWidget {
  const _QuestionTab(
      {required this.title, required this.isSelected, required this.onTap});

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: context.texts.bodyLarge.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? cs.onSurface : cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 2.0,
              width: isSelected ? 64 : 0,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteToggle extends StatelessWidget {
  const _VoteToggle(
      {required this.selectedVoteFilter, required this.onVoteFilterSelected});

  final String selectedVoteFilter;
  final ValueChanged<String> onVoteFilterSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const h = 36.0;
    final normalizedFilter = selectedVoteFilter == '랜덤 보기'
        ? CommunityFilters.vote[0]
        : selectedVoteFilter;
    final selectedIndex = CommunityFilters.vote.indexOf(normalizedFilter).clamp(
          0,
          CommunityFilters.vote.length - 1,
        );
    final widthFactor = 1 / CommunityFilters.vote.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        height: h,
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(
                  -1 + (selectedIndex * 2 / (CommunityFilters.vote.length - 1)),
                  0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  height: h,
                  decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            Row(
              children: List.generate(CommunityFilters.vote.length, (index) {
                final filter = CommunityFilters.vote[index];
                final isSelected = normalizedFilter == filter;
                final icon = switch (index) {
                  0 => Icons.style_rounded,
                  1 => Icons.menu,
                  2 => Icons.how_to_vote_rounded,
                  _ => Icons.timer_off_rounded,
                };
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onVoteFilterSelected(filter),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isSelected
                                ? cs.onPrimary
                                : cs.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            filter,
                            style: context.texts.bodyMedium.copyWith(
                                color: isSelected
                                    ? cs.onPrimary
                                    : cs.onSurface.withValues(alpha: 0.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
