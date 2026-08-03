import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_block_actions.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';

class VoteCommentsSection extends StatelessWidget {
  const VoteCommentsSection({
    super.key,
    required this.comments,
    required this.postAuthorId,
    required this.postId,
    required this.onFocusCommentInput,
    required this.onCommentLongPress,
    required this.formatTimeAgo,
  });

  final List<Comment> comments;
  final String postAuthorId;
  final String postId;
  final VoidCallback onFocusCommentInput;
  final void Function(Comment) onCommentLongPress;
  final String Function(DateTime?) formatTimeAgo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            '토론 & 의견 (${comments.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
        if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: Text('첫 의견을 작성해 투표 토론에 참여해보세요!', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ),
          )
        else
          ..._buildStructuredComments(context),
      ],
    );
  }

  List<Widget> _buildStructuredComments(BuildContext context) {
    final parentComments = comments.where((c) => c.parentId == null).toList();
    final childComments = comments.where((c) => c.parentId != null).toList();

    final widgets = <Widget>[];
    for (var i = 0; i < parentComments.length; i++) {
      final parent = parentComments[i];
      widgets.add(_buildCommentItem(context, parent, isReply: false));

      final children = childComments.where((c) => c.parentId == parent.id).toList();
      for (final child in children) {
        widgets.add(_buildCommentItem(context, child, isReply: true));
      }

      if (i < parentComments.length - 1) {
        widgets.add(const Divider(color: AppColors.surfaceContainerHigh, height: 1));
      }
    }
    return widgets;
  }

  Widget _buildCommentItem(BuildContext context, Comment comment, {required bool isReply}) {
    final currentUser = context.read<UserProvider>().currentUser;
    final isDeleted = comment.status == 'deleted';
    final provider = context.watch<CommunityProvider>();
    final isLiked = provider.likedCommentIds.contains(comment.id);
    final isBlocked = provider.isAuthorBlocked(comment.authorId);

    return GestureDetector(
      onLongPress: () => onCommentLongPress(comment),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(isReply ? 48 : 16, 16, 16, 16),
        decoration: isReply
            ? const BoxDecoration(border: Border(left: BorderSide(color: AppColors.disabled, width: 3)))
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceContainerHigh,
              backgroundImage: (!isBlocked && comment.authorAvatarUrl != null && comment.authorAvatarUrl!.isNotEmpty && !isDeleted)
                  ? NetworkImage(comment.authorAvatarUrl!)
                  : null,
              child: (comment.authorAvatarUrl == null || comment.authorAvatarUrl!.isEmpty || isDeleted || isBlocked)
                  ? Icon(isBlocked ? Icons.block_rounded : Icons.person, color: AppColors.textDisabled, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        isDeleted
                            ? '알 수 없음'
                            : isBlocked
                                ? '차단한 사용자'
                                : comment.authorNickname,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      if (comment.authorId == postAuthorId && !isDeleted && !isBlocked) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                          child: Text('작성자', style: TextStyle(color: Colors.blue[600], fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      const Spacer(),
                      if (comment.createdAt != null && !isBlocked)
                        Text(formatTimeAgo(comment.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      if (!isBlocked) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          color: Colors.grey[500],
                          onPressed: () => _showCommentOptionsSheet(context, comment),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isReply && comment.replyToNickname != null && !isDeleted && !isBlocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '@${comment.replyToNickname}',
                        style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  Text(
                    isDeleted
                        ? '삭제된 댓글입니다.'
                        : isBlocked
                            ? '차단된 사용자의 댓글입니다.'
                            : comment.content,
                    style: TextStyle(fontSize: 14, color: isDeleted ? AppColors.textDisabled : AppColors.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  if (!isDeleted && !isBlocked)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (currentUser == null) return;
                            provider.toggleCommentLike(postId, comment.id, currentUser.id);
                          },
                          child: Row(
                            children: [
                              Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 15, color: isLiked ? Colors.red : Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text('${comment.likeCount}', style: TextStyle(fontSize: 12, color: isLiked ? Colors.red : Colors.grey[500], fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            provider.setReplyingTo(comment);
                            onFocusCommentInput();
                          },
                          child: Text('답글 달기', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCommentOptionsSheet(BuildContext context, Comment comment) async {
    if (comment.status == 'deleted') return;

    final currentUser = context.read<UserProvider>().currentUser;
    final isMyComment = currentUser != null && comment.authorId == currentUser.id;

    await showCommunityOptionsSheet(
      context: context,
      title: '댓글 옵션',
      actions: [
        if (isMyComment)
          CommunityOptionAction(
            label: '삭제',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onTap: () async {
              final deleted = await context.read<CommunityProvider>().deleteComment(postId, comment.id);
              if (!context.mounted) return;
              showToast(deleted ? '댓글이 삭제되었습니다.' : '삭제에 실패했습니다.');
            },
          ),
        if (!isMyComment)
          buildCommunityBlockAction(
            context: context,
            targetUid: comment.authorId,
            targetDisplayName: comment.authorNickname,
          ),
        if (!isMyComment)
          CommunityOptionAction(
            label: '신고',
            icon: Icons.report_outlined,
            onTap: () async {
              showToast('신고가 접수되었습니다.');
            },
          ),
      ],
    );
  }
}
