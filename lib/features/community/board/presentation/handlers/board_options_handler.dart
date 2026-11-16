import 'package:parrokit/features/community/shared/presentation/widgets/community_report_actions.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_block_actions.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';
import 'package:parrokit/features/community/shared/presentation/community_delete_text.dart';

class BoardOptionsHandler {
  static Future<void> showCommentOptionsSheet({
    required BuildContext context,
    required bool isMyComment,
    required String blockedUserId,
    required String? blockedUserDisplayName,
    required Future<bool> Function() onDelete,
    required String postId,
    required String commentId,
  }) async {
    await showCommunityOptionsSheet(
      context: context,
      title: '댓글 옵션',
      actions: [
        if (isMyComment)
          CommunityOptionAction(
            label: '지우기',
            isDestructive: true,
            onTap: () async {
              final deleted = await onDelete();
              if (!context.mounted) return;
              showToast(deleted ? commentDeletedMessage : deleteFailedMessage);
            },
          ),
        if (!isMyComment)
          buildCommunityBlockAction(
            context: context,
            targetUid: blockedUserId,
            targetDisplayName: blockedUserDisplayName,
          ),
        if (!isMyComment)
          buildCommunityReportAction(
            context: context,
            postId: postId,
            commentId: commentId,
            targetAuthorId: blockedUserId,
          ),
      ],
    );
  }

  static Future<void> showPostOptionsSheet({
    required BuildContext context,
    required Post post,
    required bool isMyPost,
    required VoidCallback onEdit,
    required Future<bool> Function() onDelete,
  }) async {
    await showCommunityOptionsSheet(
      context: context,
      title: '글 옵션',
      actions: [
        if (isMyPost)
          CommunityOptionAction(
            label: '수정',
            onTap: () async {
              onEdit();
            },
          ),
        if (isMyPost)
          CommunityOptionAction(
            label: '지우기',
            isDestructive: true,
            onTap: () async {
              final deleted = await onDelete();
              if (!context.mounted) return;
              if (deleted) {
                showToast(postDeletedMessage('글'));
                Navigator.maybePop(context);
              } else {
                showToast(deleteFailedMessage);
              }
            },
          ),
        if (!isMyPost)
          buildCommunityBlockAction(
            context: context,
            targetUid: post.authorId,
            targetDisplayName: post.authorNickname,
          ),
        if (!isMyPost)
          buildCommunityReportAction(
            context: context,
            postId: post.id,
            targetAuthorId: post.authorId,
          ),
      ],
    );
  }
}
