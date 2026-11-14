import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_comment_item.dart';

Widget _item(Comment comment) => MaterialApp(
      home: Scaffold(
        body: BoardCommentItem(
          comment: comment,
          isReply: false,
          isAuthor: false,
          isBlocked: false,
          isMyComment: false,
          isLiked: false,
          currentUser: null,
          cachedUser: null,
          onLike: () {},
          onReply: () {},
          onMore: () {},
          formatTimeAgo: (_) => '방금',
        ),
      ),
    );

Comment _comment({required int likeCount}) => Comment(
      id: 'c1',
      authorId: 'u1',
      authorNickname: '앵무',
      content: '저도 해 보고 있어요!',
      likeCount: likeCount,
    );

void main() {
  testWidgets('좋아요가 0이어도 수를 보인다', (tester) async {
    await tester.pumpWidget(_item(_comment(likeCount: 0)));
    await tester.pump();

    // 전에는 0일 때만 '좋아요'라는 글자가 나와서, 한 목록 안에서 어떤 줄은
    // 숫자고 어떤 줄은 글자였다.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('좋아요'), findsNothing);
  });

  testWidgets('좋아요 수가 있으면 그 수를 보인다', (tester) async {
    await tester.pumpWidget(_item(_comment(likeCount: 4)));
    await tester.pump();

    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('그림만 있는 좋아요 단추에 이름이 있다', (tester) async {
    await tester.pumpWidget(_item(_comment(likeCount: 4)));
    await tester.pump();

    expect(find.byTooltip('좋아요'), findsOneWidget);
    expect(find.bySemanticsLabel('좋아요 4'), findsOneWidget);
  });
}
