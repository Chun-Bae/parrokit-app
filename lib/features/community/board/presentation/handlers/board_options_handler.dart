import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_block_actions.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';

class BoardOptionsHandler {
  static Future<void> showCommentOptionsSheet({
    required BuildContext context,
    required bool isMyComment,
    required String blockedUserId,
    required String? blockedUserDisplayName,
    required Future<bool> Function() onDelete,
  }) async {
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
              final deleted = await onDelete();
              if (!context.mounted) return;
              showToast(deleted ? '댓글이 삭제되었습니다.' : '삭제에 실패했습니다.');
            },
          ),
        if (!isMyComment)
          buildCommunityBlockAction(
            context: context,
            targetUid: blockedUserId,
            targetDisplayName: blockedUserDisplayName,
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
            icon: Icons.edit_outlined,
            onTap: () async {
              onEdit();
            },
          ),
        if (isMyPost)
          CommunityOptionAction(
            label: '삭제',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onTap: () async {
              final deleted = await onDelete();
              if (!context.mounted) return;
              if (deleted) {
                showToast('게시글이 삭제되었습니다.');
                Navigator.maybePop(context);
              } else {
                showToast('삭제에 실패했습니다.');
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
