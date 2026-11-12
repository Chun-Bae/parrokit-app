import 'package:flutter/material.dart';

class CommunityNotificationChip extends StatelessWidget {
  final String boardType;

  const CommunityNotificationChip({
    super.key,
    required this.boardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _labelForBoardType(boardType);

    return Chip(
      label: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.16)),
      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  String _labelForBoardType(String boardType) {
    switch (boardType) {
      case 'question':
        return '질문';
      case 'vote':
        return '투표';
      default:
        // 커뮤니티 탭 이름이 '게시판'이다. 전에는 '일반'이라 게시판 카테고리
        // (자유·추천해요·꿀팁…)에 없는 이름이 칩에 붙었다.
        return '게시판';
    }
  }
}
