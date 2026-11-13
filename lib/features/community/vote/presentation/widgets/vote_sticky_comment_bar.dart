import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class VoteStickyCommentBar extends StatelessWidget {
  const VoteStickyCommentBar({
    super.key,
    required this.commentController,
    required this.commentFocusNode,
    required this.canSubmit,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController commentController;
  final FocusNode commentFocusNode;
  final bool canSubmit;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final currentUser = context.watch<UserProvider>().currentUser;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.replyingTo != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.tokens.surfaceContainer,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${provider.replyingTo?.authorNickname} 님에게 답글 남기는 중',
                    style: context.texts.labelMedium
                        .copyWith(color: context.tokens.textSecondary),
                  ),
                ),
                GestureDetector(
                  onTap: () => provider.setReplyingTo(null),
                  child: Icon(Icons.close,
                      size: 16, color: context.tokens.textTertiary),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: context.tokens.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border(
                top: BorderSide(
                    color: context.tokens.surfaceContainerHigh, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SafeArea(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: context.tokens.surfaceContainerHigh,
                  backgroundImage: (currentUser?.photoUrl != null &&
                          currentUser!.photoUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(currentUser.photoUrl!)
                      : null,
                  child: (currentUser?.photoUrl == null ||
                          currentUser!.photoUrl!.isEmpty)
                      ? Icon(Icons.person,
                          color: context.tokens.textDisabled, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.tokens.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border:
                          Border.all(color: context.tokens.surface, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: commentController,
                      focusNode: commentFocusNode,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmit(),
                      decoration: const InputDecoration(
                        hintText: '투표 의견 남기기...',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                      ),
                      style: context.texts.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '보내기',
                  icon: Icon(
                    Icons.send_rounded,
                    color: canSubmit
                        ? context.tokens.primary
                        : context.tokens.textDisabled,
                    size: 22,
                  ),
                  onPressed: canSubmit ? onSubmit : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
