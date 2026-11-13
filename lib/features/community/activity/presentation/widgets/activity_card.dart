import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/activity_item.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final ActivityItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBoardBadge(context),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: context.texts.titleMedium
                        .copyWith(color: colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.content,
              style: context.texts.bodyMedium
                  .copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  DateFormat('yyyy.MM.dd HH:mm').format(item.createdAt),
                  style: context.texts.bodySmall
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                _buildCountIcon(
                    context, Icons.thumb_up_alt_outlined, item.likeCount),
                const SizedBox(width: 12),
                _buildCountIcon(
                  context,
                  Icons.chat_bubble_outline_rounded,
                  item.commentCount,
                ),
                const SizedBox(width: 12),
                _buildCountIcon(
                    context, Icons.remove_red_eye_outlined, item.viewCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountIcon(BuildContext context, IconData icon, int count) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: context.texts.bodySmall
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildBoardBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color textColor;
    String label;

    switch (item.boardType) {
      case 'question':
        bgColor = isDark
            ? colorScheme.secondaryContainer
            : AppColors.communityQuestionAccentSoft;
        textColor = isDark
            ? colorScheme.onSecondaryContainer
            : AppColors.communityQuestionAccent;
        label = '질문';
        break;
      case 'vote':
        bgColor = isDark
            ? colorScheme.tertiaryContainer
            : AppColors.communityVoteAccentSoft;
        textColor = isDark
            ? colorScheme.onTertiaryContainer
            : AppColors.communityVoteAccent;
        label = '투표';
        break;
      case 'board':
      default:
        bgColor = isDark
            ? colorScheme.primaryContainer
            : AppColors.communityBoardAccentSoft;
        textColor = isDark
            ? colorScheme.onPrimaryContainer
            : AppColors.communityBoardAccent;
        // 커뮤니티 탭 이름이 '게시판'이다. 알림 칩과 같은 이름으로 맞춘다(예전 '일반').
        label = '게시판';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: context.texts.labelSmall.copyWith(color: textColor),
      ),
    );
  }
}
