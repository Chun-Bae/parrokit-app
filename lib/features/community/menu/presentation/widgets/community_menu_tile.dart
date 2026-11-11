import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/features/community/menu/domain/entities/community_menu_entry.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class CommunityMenuTile extends StatelessWidget {
  const CommunityMenuTile({
    super.key,
    required this.item,
    this.onTap,
  });

  final CommunityMenuEntry item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _backgroundColorOf(context, item.colorKey),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(_iconOf(item.iconKey),
            color: _iconColorOf(context, item.colorKey), size: 20),
      ),
      title: Text(
        item.title,
        style: context.texts.titleMedium.copyWith(color: colorScheme.onSurface),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.tokens.textDisabled,
        size: 24,
      ),
      onTap: onTap ??
          () {
            if (item.routePath != null) {
              context.push(item.routePath!);
              return;
            }
            if (item.boardType != null && item.activityType != null) {
              context.push(
                AppRoutes.communityActivityPathOf(
                  boardType: item.boardType!,
                  activityType: item.activityType!,
                ),
              );
            }
          },
    );
  }
}

IconData _iconOf(String iconKey) {
  switch (iconKey) {
    case 'article':
      return Icons.article_rounded;
    case 'chat_bubble':
      return Icons.chat_bubble_rounded;
    case 'thumb_up':
      return Icons.thumb_up_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    case 'bookmark':
      return Icons.bookmark_rounded;
    case 'help':
      return Icons.help_rounded;
    case 'forum':
      return Icons.forum_rounded;
    case 'chat':
      return Icons.chat_rounded;
    case 'how_to_vote':
      return Icons.how_to_vote_rounded;
    case 'campaign':
      return Icons.campaign_rounded;
    case 'notifications':
      return Icons.notifications_rounded;
    case 'shield':
      return Icons.shield_rounded;
    default:
      return Icons.circle;
  }
}

Color _iconColorOf(BuildContext context, String colorKey) {
  switch (colorKey) {
    case 'board':
      return AppColors.communityBoardAccent;
    case 'question':
      return AppColors.communityQuestionAccent;
    case 'vote':
      return AppColors.communityVoteAccent;
    default:
      return context.tokens.textSecondary;
  }
}

Color _backgroundColorOf(BuildContext context, String colorKey) {
  switch (colorKey) {
    case 'board':
      return AppColors.communityBoardAccentSoft;
    case 'question':
      return AppColors.communityQuestionAccentSoft;
    case 'vote':
      return AppColors.communityVoteAccentSoft;
    default:
      return context.tokens.surfaceContainerHigh;
  }
}
