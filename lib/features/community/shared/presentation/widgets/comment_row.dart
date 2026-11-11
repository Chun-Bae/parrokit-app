import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';

/// 댓글 한 칸의 바깥 틀.
///
/// 답글이면 왼쪽으로 들여쓰고 **들여쓴 자리에** 세로 안내선을 그린다.
/// 게시판·질문·투표 댓글이 모두 이 틀을 쓴다.
///
/// 전에는 네 화면이 각자 `Container`에 왼쪽 패딩과 왼쪽 테두리를 같이 줬다.
/// 패딩은 컨테이너 안쪽이고 테두리는 바깥 끝이라, 안내선이 화면 맨 왼쪽에
/// 붙고 글만 안쪽으로 들어가 있었다.
class CommentRow extends StatelessWidget {
  const CommentRow({
    super.key,
    required this.isReply,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  final bool isReply;
  final Widget child;

  /// 안내선 안쪽 여백. 답글이 아니면 화면 가장자리부터의 여백이 된다.
  final EdgeInsets padding;

  /// 답글을 들여쓰는 너비. 안내선은 이 자리에 그려진다.
  static const double replyIndent = 32;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: isReply ? replyIndent : 0),
        child: Container(
          padding: padding,
          decoration: isReply
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(color: context.tokens.disabled, width: 3),
                  ),
                )
              : null,
          child: child,
        ),
      );
}
