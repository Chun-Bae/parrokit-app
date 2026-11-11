import 'package:flutter/material.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class BoardCommentInputBar extends StatelessWidget {
  const BoardCommentInputBar({
    super.key,
    required this.replyingTo,
    required this.onCancelReply,
    required this.controller,
    required this.focusNode,
    required this.onFocusInput,
    required this.onChanged,
    required this.onSubmit,
    required this.canSubmit,
    required this.sendAccent,
    this.backgroundColor,
  });

  final Comment? replyingTo;
  final VoidCallback onCancelReply;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onFocusInput;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final bool canSubmit;
  final Color sendAccent;

  /// 비우면 테마의 기본 표면색을 쓴다.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? context.tokens.surface,
        border: Border(top: BorderSide(color: context.tokens.disabled)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: context.tokens.surfaceContainer,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${replyingTo!.authorNickname}님에게 답글 남기는 중',
                      style: context.texts.labelMedium
                          .copyWith(color: context.tokens.textSecondary),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: Icon(Icons.close,
                        size: 18, color: context.tokens.textTertiary),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.photo_outlined, size: 32),
                  color: context.tokens.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: onFocusInput,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: onChanged,
                              onSubmitted: (_) => onSubmit(),
                              style: context.texts.titleMedium
                                  .copyWith(color: colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: '댓글을 입력해주세요.',
                                fillColor: colorScheme.surfaceContainerHigh,
                                hintStyle: context.texts.titleLarge.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              textInputAction: TextInputAction.send,
                            ),
                          ),
                          GestureDetector(
                            onTap: canSubmit ? onSubmit : null,
                            child: Icon(
                              Icons.keyboard_return_rounded,
                              color: canSubmit
                                  ? sendAccent
                                  : context.tokens.textTertiary,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
