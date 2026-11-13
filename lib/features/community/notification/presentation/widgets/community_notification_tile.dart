import 'package:flutter/material.dart';
import 'package:parrokit/features/community/notification/domain/entities/community_notification_item.dart';
import 'community_notification_chip.dart';

/// 예전 서버 문구의 게시판 이름을 지금 이름으로 바꿔 보여준다.
///
/// 서버 함수는 99813053에서 '일반' → '게시판'으로 고쳤지만, 그 전에 만들어져
/// 저장된 알림은 "일반에 새 댓글이 달렸어요"를 그대로 들고 있다. 탭과 칩은
/// '게시판'이라 같은 알림 안에서 이름이 달라 보였다. 저장된 값은 건드리지 않고
/// 보여줄 때만 바꾼다. 게시판 글 알림에서만, 서버가 쓰던 꼴('일반에 ', '일반의 ')만
/// 바꾼다(닉네임 등 다른 곳의 '일반'은 그대로).
String displayNotificationText(String text, String boardType) {
  if (boardType != 'board') return text;
  return text.replaceAll('일반에 ', '게시판에 ').replaceAll('일반의 ', '게시판의 ');
}

class CommunityNotificationTile extends StatelessWidget {
  final CommunityNotificationItem item;
  final VoidCallback onTap;

  const CommunityNotificationTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: item.isRead
          ? colorScheme.surface
          : colorScheme.primary.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLeadingIcon(colorScheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title.isEmpty
                                ? '새 알림'
                                : displayNotificationText(
                                    item.title, item.boardType),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _UnreadDot(isRead: item.isRead),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayNotificationText(item.body, item.boardType),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CommunityNotificationChip(boardType: item.boardType),
                        const Spacer(),
                        Text(
                          _formatRelativeTime(item.createdAt),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(ColorScheme colorScheme) {
    final iconData = _iconForBoardType(item.boardType);
    final backgroundColor = _backgroundColorForBoardType(colorScheme, item.boardType);
    final foregroundColor = _foregroundColorForBoardType(colorScheme, item.boardType);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 20, color: foregroundColor),
    );
  }

  IconData _iconForBoardType(String boardType) {
    switch (boardType) {
      case 'question':
        return Icons.quiz_rounded;
      case 'vote':
        return Icons.how_to_vote_rounded;
      default:
        return Icons.forum_rounded;
    }
  }

  Color _backgroundColorForBoardType(ColorScheme colorScheme, String boardType) {
    switch (boardType) {
      case 'question':
        return colorScheme.secondaryContainer.withValues(alpha: 0.55);
      case 'vote':
        return colorScheme.tertiaryContainer.withValues(alpha: 0.45);
      default:
        return colorScheme.primaryContainer.withValues(alpha: 0.45);
    }
  }

  Color _foregroundColorForBoardType(ColorScheme colorScheme, String boardType) {
    switch (boardType) {
      case 'question':
        return colorScheme.onSecondaryContainer;
      case 'vote':
        return colorScheme.onTertiaryContainer;
      default:
        return colorScheme.onPrimaryContainer;
    }
  }

  String _formatRelativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    // 글·댓글 시각과 같은 모양으로(5차, 예전 '11/7').
    final now = DateTime.now();
    return createdAt.year == now.year
        ? '${createdAt.month}월 ${createdAt.day}일'
        : '${createdAt.year}년 ${createdAt.month}월 ${createdAt.day}일';
  }
}

class _UnreadDot extends StatelessWidget {
  final bool isRead;

  const _UnreadDot({required this.isRead});

  @override
  Widget build(BuildContext context) {
    if (isRead) {
      return const SizedBox(width: 8);
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
