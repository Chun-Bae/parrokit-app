import 'package:flutter/material.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class QuestionStickyReplyBar extends StatelessWidget {
  const QuestionStickyReplyBar({
    super.key,
    required this.replyController,
    required this.replyFocusNode,
    required this.onSubmitReply,
  });

  final TextEditingController replyController;
  final FocusNode replyFocusNode;
  final VoidCallback onSubmitReply;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = context.watch<UserProvider>().currentUser;
    final provider = context.watch<CommunityProvider>();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border:
            Border(top: BorderSide(color: context.tokens.surfaceContainerHigh)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider.replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: context.tokens.surfaceContainer,
              child: Row(
                children: [
                  Text(
                    '${provider.replyingTo!.authorNickname}님에게 답글 남기는 중',
                    style: context.texts.labelMedium
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => provider.setReplyingTo(null),
                    child: Icon(Icons.close,
                        size: 16, color: context.tokens.textDisabled),
                  ),
                ],
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: context.tokens.surfaceContainerHigh,
                    backgroundImage: currentUser?.photoUrl != null
                        ? NetworkImage(currentUser!.photoUrl!)
                        : null,
                    child: currentUser?.photoUrl == null
                        ? Icon(Icons.person,
                            size: 14, color: colorScheme.onSurfaceVariant)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      focusNode: replyFocusNode,
                      decoration: InputDecoration(
                        hintText: '답글 남기기...',
                        hintStyle: context.texts.bodyMedium
                            .copyWith(color: colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                      ),
                      style: context.texts.bodyMedium
                          .copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                  TextButton(
                    onPressed: onSubmitReply,
                    child: Text(
                      '답글',
                      style: context.texts.bodyMedium
                          .copyWith(color: context.tokens.warning),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
