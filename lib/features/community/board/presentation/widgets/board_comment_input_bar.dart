import 'package:flutter/material.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/features/community/shared/presentation/comment_input_text.dart';
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
                      replyingToLabel(replyingTo!.authorNickname),
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
                // 댓글 사진 버튼은 뺐다(5차). 기능이 없어 흐린 아이콘만 있었다(원칙 5).
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
                              // 치는 글도 읽는 글과 같은 굵기로(5차).
                              style: context.texts.bodyReading
                                  .copyWith(color: colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: commentInputHint(
                                    replying: replyingTo != null),
                                fillColor: colorScheme.surfaceContainerHigh,
                                // 안내 글자는 친 글자와 같은 크기로. 예전엔 titleLarge라
                                // 친 글자보다 크고 굵었다(5차).
                                hintStyle: context.texts.bodyReading.copyWith(
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
                          // 예전엔 줄바꿈(↵) 아이콘에 이름이 없어 보내기 버튼으로
                          // 읽히지 않았다(5차). 보내기 아이콘과 툴팁을 단다.
                          IconButton(
                            key: const ValueKey('comment-send'),
                            tooltip: commentSendTooltip(
                                replying: replyingTo != null),
                            onPressed: canSubmit ? onSubmit : null,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.send_rounded,
                              color: canSubmit
                                  ? sendAccent
                                  : context.tokens.textTertiary,
                              size: 26,
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
