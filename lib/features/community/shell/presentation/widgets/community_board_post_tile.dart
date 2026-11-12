import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class CommunityBoardPostTile extends StatelessWidget {
  final Post post;

  /// 글마다 붙는 분류 칩. 분류를 골라 거른 목록에서는 모든 글이 같은 분류라
  /// 같은 칩이 줄마다 반복된다. 그때는 숨긴다.
  final bool showCategory;

  const CommunityBoardPostTile({
    super.key,
    required this.post,
    this.showCategory = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final userProvider = context.watch<UserProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final authorName = resolveCommunityAuthorName(
      post: post,
      provider: provider,
      userProvider: userProvider,
    );

    return InkWell(
      onTap: () => context.push(AppRoutes.communityBoardViewPathOf(post.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCategory) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  post.category,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              post.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              post.snippet,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$authorName · ${formatCommunityTimeAgo(post.createdAt)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: [
                    _Metric(icon: Icons.remove_red_eye, value: post.viewCount),
                    const SizedBox(width: 12),
                    _Metric(icon: Icons.thumb_up, value: post.likeCount),
                    const SizedBox(width: 12),
                    _Metric(icon: Icons.chat_bubble, value: post.commentCount),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final int value;

  const _Metric({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 14, color: colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
