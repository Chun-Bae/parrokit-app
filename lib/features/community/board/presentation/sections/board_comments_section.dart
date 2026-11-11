import 'package:flutter/material.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_comment_item.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_comments_empty_state.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class BoardCommentsSection extends StatelessWidget {
  const BoardCommentsSection({
    super.key,
    required this.comments,
    required this.postAuthorId,
    required this.postId,
    required this.onFocusCommentInput,
    required this.onCommentMore,
    required this.formatTimeAgo,
  });

  final List<Comment> comments;
  final String postAuthorId;
  final String postId;
  final VoidCallback onFocusCommentInput;
  final void Function(Comment) onCommentMore;
  final String Function(DateTime?) formatTimeAgo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Divider(
            height: 1, thickness: 5, color: colorScheme.surfaceContainerHigh),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 28, 0),
          child: Text(
            '댓글 ${comments.length}',
            style: context.texts.titleLarge
                .copyWith(color: context.tokens.textTertiary),
          ),
        ),
        if (comments.isEmpty) ...[
          BoardCommentsEmptyState(onTap: onFocusCommentInput),
        ] else ...[
          const SizedBox(height: 8),
          ..._buildStructuredComments(context),
        ],
      ],
    );
  }

  List<Widget> _buildStructuredComments(BuildContext context) {
    final parentComments = comments.where((c) => c.parentId == null).toList();
    final childComments = comments.where((c) => c.parentId != null).toList();

    final widgets = <Widget>[];
    for (final parent in parentComments) {
      widgets.add(_buildCommentItem(context, parent, isReply: false));
      final children =
          childComments.where((c) => c.parentId == parent.id).toList();
      for (final child in children) {
        widgets.add(_buildCommentItem(context, child, isReply: true));
      }
    }
    return widgets;
  }

  Widget _buildCommentItem(BuildContext context, Comment comment,
      {required bool isReply}) {
    final currentUser = context.read<UserProvider>().currentUser;
    final isMyComment =
        currentUser != null && comment.authorId == currentUser.id;
    final provider = context.watch<CommunityProvider>();
    final isLiked = provider.likedCommentIds.contains(comment.id);

    return BoardCommentItem(
      comment: comment,
      isReply: isReply,
      isAuthor: comment.authorId == postAuthorId,
      isBlocked: provider.isAuthorBlocked(comment.authorId),
      isMyComment: isMyComment,
      isLiked: isLiked,
      currentUser: currentUser,
      cachedUser: provider.getCachedUser(comment.authorId),
      onLike: () {
        if (currentUser == null) return;
        context
            .read<CommunityProvider>()
            .toggleCommentLike(postId, comment.id, currentUser.id);
      },
      onReply: () {
        context.read<CommunityProvider>().setReplyingTo(comment);
        onFocusCommentInput();
      },
      onMore: () => onCommentMore(comment),
      formatTimeAgo: formatTimeAgo,
    );
  }
}
