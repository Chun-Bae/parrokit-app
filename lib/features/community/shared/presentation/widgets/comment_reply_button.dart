// 댓글·답글 줄의 '답글 쓰기'. 세 화면이 같은 모양을 쓰도록 모아 둔다.
//
// 전에는 화면마다 달랐다. 게시판은 말풍선 아이콘 + 글자, 투표는 글자만,
// 질문은 아이콘만(툴팁)이라 질문 화면에서는 무엇을 하는 버튼인지 눌러 봐야
// 알 수 있었다(5차, 원칙 '버튼에 이름 붙이기').

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class CommentReplyButton extends StatelessWidget {
  const CommentReplyButton({
    super.key,
    required this.onTap,
    required this.color,
  });

  final VoidCallback onTap;

  /// 아이콘과 글자에 함께 쓰는 색. 화면마다 댓글 줄 색이 조금 다르다.
  final Color color;

  static const String label = '답글 쓰기';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: context.texts.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}
