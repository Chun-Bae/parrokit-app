import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:shimmer/shimmer.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

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
        ? '차단한 사용자'
        : (isMyComment ? currentUser?.displayName : cachedUser?.displayName) ??
            comment.authorNickname;

    return Container(
      padding: EdgeInsets.fromLTRB(isReply ? 52 : 18, 18, 18, 0),
      decoration: isReply
          ? const BoxDecoration(
              border:
                  Border(left: BorderSide(color: AppColors.disabled, width: 3)),
            )
          : null,
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
                            color: AppColors.textDisabled),
                      ),
                    )
                  : Center(
                      child: isDeleted
                          ? const SizedBox()
                          : Icon(
                              isBlocked ? Icons.block_rounded : Icons.person,
                              size: isReply ? 20 : 26,
                              color: AppColors.textDisabled,
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
                    Text(
                      isDeleted
                          ? '(삭제됨)'
                          : isBlocked
                              ? '차단한 사용자'
                              : displayName,
                      style: context.texts.titleMedium.copyWith(
                          color: isDeleted
                              ? AppColors.textDisabled
                              : colorScheme.onSurface),
                    ),
                    if (!isDeleted && !isBlocked && isAuthor) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('작성자',
                            style: context.texts.labelSmall
                                .copyWith(color: AppColors.primary)),
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
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('내 댓글',
                            style: context.texts.labelSmall
                                .copyWith(color: AppColors.textTertiary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (!isDeleted && !isBlocked)
                  Text(
                    formatTimeAgo(comment.createdAt),
                    style: context.texts.labelMedium
                        .copyWith(color: AppColors.textDisabled),
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
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                Text(
                  isDeleted
                      ? '삭제된 댓글입니다.'
                      : isBlocked
                          ? '차단된 사용자의 댓글입니다.'
                          : comment.content,
                  style: context.texts.bodyLarge.copyWith(
                      color: isDeleted
                          ? AppColors.textDisabled
                          : colorScheme.onSurface,
                      height: 1.35),
                ),
                const SizedBox(height: 10),
                if (!isDeleted && !isBlocked)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                                color: isLiked
                                    ? AppColors.danger
                                    : AppColors.textDisabled),
                            const SizedBox(width: 4),
                            Text(
                              comment.likeCount > 0
                                  ? '${comment.likeCount}'
                                  : '좋아요',
                              style: context.texts.labelMedium.copyWith(
                                  color: isLiked
                                      ? AppColors.danger
                                      : AppColors.textDisabled),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: onReply,
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 16, color: AppColors.textDisabled),
                            SizedBox(width: 4),
                            Text('답글쓰기',
                                style: context.texts.labelMedium
                                    .copyWith(color: AppColors.textDisabled)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (!isDeleted && !isBlocked)
            IconButton(
              onPressed: onMore,
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textDisabled, size: 20),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
