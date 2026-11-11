import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:shimmer/shimmer.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class BoardPostAuthorRow extends StatelessWidget {
  const BoardPostAuthorRow({
    super.key,
    required this.post,
    required this.currentUser,
    required this.cachedAuthor,
    required this.isMe,
    required this.timeAgoText,
  });

  final Post post;
  final AppUser? currentUser;
  final AppUser? cachedAuthor;
  final bool isMe;
  final String timeAgoText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final photoUrl = (isMe ? currentUser?.photoUrl : cachedAuthor?.photoUrl) ??
        post.authorAvatarUrl;
    final displayName =
        (isMe ? currentUser?.displayName : cachedAuthor?.displayName) ??
            post.authorNickname;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHigh,
            ),
            child: ClipOval(
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: colorScheme.surfaceContainerHigh,
                        highlightColor: colorScheme.surfaceContainer,
                        child: Container(color: colorScheme.surface),
                      ),
                      errorWidget: (context, url, error) => Icon(Icons.person,
                          size: 30, color: colorScheme.onSurfaceVariant),
                    )
                  : Icon(Icons.person,
                      size: 30, color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: context.texts.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                timeAgoText,
                style: context.texts.bodyLarge
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
