import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/features/community/shared/presentation/community_delete_text.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:shimmer/shimmer.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/comment_reply_button.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/comment_row.dart';

class BoardCommentItem extends StatelessWidget {
  const BoardCommentItem({
    super.key,
    required this.comment,
    required this.isReply,
    required this.isAuthor,
    required this.isBlocked,
    required this.isMyComment,
    required this.isLiked,
    required this.currentUser,
    required this.cachedUser,
    required this.onLike,
    required this.onReply,
    required this.onMore,
    required this.formatTimeAgo,
  });

  final Comment comment;
  final bool isReply;
  final bool isAuthor;
  final bool isBlocked;
  final bool isMyComment;
  final bool isLiked;
  final AppUser? currentUser;
  final AppUser? cachedUser;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onMore;
  final String Function(DateTime?) formatTimeAgo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDeleted = comment.status == 'deleted';
    final photoUrl = isBlocked
        ? null
        : (isMyComment ? currentUser?.photoUrl : cachedUser?.photoUrl) ??
            comment.authorAvatarUrl;
    final displayName = isBlocked
        ? blockedAuthorName
        : (isMyComment ? currentUser?.displayName : cachedUser?.displayName) ??
            comment.authorNickname;

    return CommentRow(
      isReply: isReply,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isReply ? 36 : 44,
            height: isReply ? 36 : 44,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHigh),
            child: ClipOval(
              child: (photoUrl != null &&
                      photoUrl.isNotEmpty &&
                      !isDeleted &&
                      !isBlocked)
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: colorScheme.surfaceContainerHigh,
                        highlightColor: colorScheme.surfaceContainer,
                        child: Container(color: colorScheme.surface),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(Icons.person,
                            size: isReply ? 20 : 26,
                            color: context.tokens.textDisabled),
                      ),
                    )
                  : Center(
                      child: isDeleted
                          ? const SizedBox()
                          : Icon(
                              isBlocked ? Icons.block_rounded : Icons.person,
                              size: isReply ? 20 : 26,
                              color: context.tokens.textDisabled,
                            ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 지운 댓글에는 이름을 적지 않는다. 게시판은 '(삭제됨)',
                    // 투표는 '알 수 없음'이라 적었는데, 앞은 예전 말이고
                    // 뒤는 닉네임 없는 사람과 헷갈렸다. 아래 '지운 댓글이에요.'
                    // 한 줄이면 충분하다(5차 403).
                    if (!isDeleted)
                      Text(
                        isBlocked ? blockedAuthorName : displayName,
                        style: context.texts.titleMedium
                            .copyWith(color: colorScheme.onSurface),
                      ),
                    if (!isDeleted && !isBlocked && isAuthor) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: context.tokens.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.xs)),
                        child: Text('작성자',
                            style: context.texts.labelSmall
                                .copyWith(color: context.tokens.primary)),
                      ),
                    ],
                    if (!isDeleted &&
                        !isBlocked &&
                        isMyComment &&
                        !isAuthor) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: context.tokens.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppRadius.xs)),
                        child: Text('내 댓글',
                            style: context.texts.labelSmall
                                .copyWith(color: context.tokens.textTertiary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (!isDeleted && !isBlocked)
                  Text(
                    formatTimeAgo(comment.createdAt),
                    style: context.texts.labelMedium
                        .copyWith(color: context.tokens.textDisabled),
                  ),
                const SizedBox(height: 8),
                if (!isDeleted &&
                    !isBlocked &&
                    isReply &&
                    comment.replyToNickname != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '@${comment.replyToNickname}',
                      style: context.texts.bodyMedium
                          .copyWith(color: context.tokens.primary),
                    ),
                  ),
                Text(
                  isDeleted
                      ? deletedCommentText
                      : isBlocked
                          ? blockedCommentText
                          : comment.content,
                  // 댓글도 이름·날짜와 같이 굵어서 위아래 구분이 없었다(5차).
                  style: context.texts.bodyReading.copyWith(
                      color: isDeleted
                          ? context.tokens.textDisabled
                          : colorScheme.onSurface,
                      height: 1.45),
                ),
                const SizedBox(height: 10),
                if (!isDeleted && !isBlocked)
                  Row(
                    children: [
                      // 한 목록 안에서 어떤 댓글은 '4', 어떤 댓글은 '좋아요'로
                      // 보여 같은 줄인데 다른 것처럼 읽혔다. 늘 수를 보이고,
                      // 무엇을 누르는지는 이름으로 알린다(5차).
                      Tooltip(
                        message: '좋아요',
                        child: Semantics(
                          button: true,
                          label: '좋아요 ${comment.likeCount}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: onLike,
                            child: Row(
                              children: [
                                Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                    color: isLiked
                                        ? context.tokens.danger
                                        : context.tokens.textDisabled),
                                const SizedBox(width: 4),
                                Text(
                                  '${comment.likeCount}',
                                  style: context.texts.labelMedium.copyWith(
                                      color: isLiked
                                          ? context.tokens.danger
                                          : context.tokens.textDisabled),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      CommentReplyButton(
                        onTap: onReply,
                        color: context.tokens.textDisabled,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (!isDeleted && !isBlocked)
            IconButton(
              tooltip: '댓글 옵션',
              onPressed: onMore,
              icon: Icon(Icons.more_vert_rounded,
                  color: context.tokens.textDisabled, size: 20),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
