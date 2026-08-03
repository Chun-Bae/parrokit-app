import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_block_actions.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';

class QuestionRepliesSection extends StatelessWidget {
  const QuestionRepliesSection({
    super.key,
    required this.question,
    required this.answers,
    required this.onAcceptAnswer,
    required this.onFocusReplyInput,
    required this.formatTimeAgo,
  });

  final Post question;
  final List<Comment> answers;
  final void Function(Comment answer) onAcceptAnswer;
  final VoidCallback onFocusReplyInput;
  final String Function(DateTime?) formatTimeAgo;

  @override
  Widget build(BuildContext context) {
    if (answers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            '아직 답변이 없습니다.\n첫 번째 답변을 남겨보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDisabled, fontSize: 14),
          ),
        ),
      );
    }

    final parentAnswers = answers.where((c) => c.parentId == null).toList();
    final childAnswers = answers.where((c) => c.parentId != null).toList();
    parentAnswers.sort((a, b) => (b.isAccepted ? 1 : 0).compareTo(a.isAccepted ? 1 : 0));

    final widgets = <Widget>[];
    for (var i = 0; i < parentAnswers.length; i++) {
      final parent = parentAnswers[i];
      widgets.add(_buildReplyItem(context, parent, isReply: false));

      final children = childAnswers.where((c) => c.parentId == parent.id).toList();
      for (final child in children) {
        widgets.add(_buildReplyItem(context, child, isReply: true));
      }

      if (i < parentAnswers.length - 1 || children.isNotEmpty) {
        widgets.add(const Divider(height: 1, color: AppColors.surfaceContainerHigh));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  }

  Widget _buildReplyItem(BuildContext context, Comment answer, {required bool isReply}) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = context.read<UserProvider>().currentUser;
    final isMe = currentUser != null && question.authorId == currentUser.id;
    final provider = context.read<CommunityProvider>();
    final isBlocked = provider.isAuthorBlocked(answer.authorId);

    final answererName = (answer.authorId == currentUser?.id)
        ? (currentUser?.displayName ?? answer.authorNickname)
        : (provider.getCachedUser(answer.authorId)?.displayName ?? answer.authorNickname);

    final answererAvatar = (answer.authorId == currentUser?.id)
        ? (currentUser?.photoUrl ?? answer.authorAvatarUrl)
        : (provider.getCachedUser(answer.authorId)?.photoUrl ?? answer.authorAvatarUrl);

    return Container(
      padding: EdgeInsets.fromLTRB(isReply ? 46 : 16, 16, 16, 16),
      decoration: isReply
          ? const BoxDecoration(border: Border(left: BorderSide(color: AppColors.disabled, width: 3)))
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundColor: AppColors.surfaceContainerHigh,
                backgroundImage: (!isBlocked && answererAvatar != null) ? NetworkImage(answererAvatar) : null,
                child: answererAvatar == null || isBlocked
                    ? Icon(isBlocked ? Icons.block_rounded : Icons.person, size: isReply ? 14 : 18, color: colorScheme.onSurfaceVariant)
                    : null,
              ),
              if (!isReply) Container(width: 2, height: 40, color: AppColors.surfaceContainerHigh),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(isBlocked ? '차단한 사용자' : answererName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    const Spacer(),
                    if (!isBlocked) ...[
                      Text(formatTimeAgo(answer.createdAt), style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        color: colorScheme.onSurfaceVariant,
                        onPressed: () => _showAnswerOptionsSheet(context, answer),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (answer.isAccepted) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, color: AppColors.success, size: 12),
                        const SizedBox(width: 4),
                        const Text('채택된 답변', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (isReply && answer.replyToNickname != null && !isBlocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '@${answer.replyToNickname}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                Text(
                  isBlocked ? '차단된 사용자의 답변입니다.' : answer.content,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 12),
                if (!isBlocked)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              provider.likedCommentIds.contains(answer.id) ? Icons.bolt : Icons.bolt_outlined,
                              size: 18,
                              color: provider.likedCommentIds.contains(answer.id) ? AppColors.warning : AppColors.textSecondary,
                            ),
                            onPressed: () {
                              if (currentUser != null) {
                                provider.toggleCommentLike(question.id, answer.id, currentUser.id);
                              } else {
                                showToast('로그인이 필요합니다.');
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          Text('${answer.likeCount}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.mode_comment_outlined, size: 18, color: AppColors.textSecondary),
                            onPressed: () {
                              provider.setReplyingTo(answer);
                              onFocusReplyInput();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      if (!isReply && isMe && question.questionStatus == 'waiting' && answer.authorId != question.authorId)
                        GestureDetector(
                          onTap: () => onAcceptAnswer(answer),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(6)),
                            child: const Text('채택하기', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAnswerOptionsSheet(BuildContext context, Comment answer) async {
    final currentUser = context.read<UserProvider>().currentUser;
    final isMyComment = currentUser != null && answer.authorId == currentUser.id;

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
              final deleted = await context.read<CommunityProvider>().deleteComment(question.id, answer.id);
              if (!context.mounted) return;
              showToast(deleted ? '댓글이 삭제되었습니다.' : '삭제에 실패했습니다.');
            },
          ),
        if (!isMyComment)
          buildCommunityBlockAction(
            context: context,
            targetUid: answer.authorId,
            targetDisplayName: answer.authorNickname,
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
