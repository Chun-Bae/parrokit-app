// 게시판 댓글 입력줄(5차): 보내기 버튼이 줄바꿈 아이콘에 이름이 없었고, 안내
// 글자가 친 글자보다 컸다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_comment_input_bar.dart';

void main() {
  Future<int Function()> pump(WidgetTester tester, {required bool canSubmit}) async {
    var sent = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BoardCommentInputBar(
          replyingTo: null,
          onCancelReply: () {},
          controller: TextEditingController(),
          focusNode: FocusNode(),
          onFocusInput: () {},
          onChanged: (_) {},
          onSubmit: () => sent++,
          canSubmit: canSubmit,
          sendAccent: Colors.blue,
        ),
      ),
    ));
    return () => sent;
  }

  testWidgets('보내기 버튼은 이름이 있고, 쓸 수 있을 때만 보낸다', (tester) async {
    final sent = await pump(tester, canSubmit: true);
    expect(find.byTooltip('댓글 보내기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comment-send')));
    expect(sent(), 1);

    final none = await pump(tester, canSubmit: false);
    await tester.tap(find.byKey(const ValueKey('comment-send')));
    expect(none(), 0);
  });

  testWidgets('안내 글자는 친 글자와 같은 크기', (tester) async {
    await pump(tester, canSubmit: false);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.hintStyle!.fontSize, field.style!.fontSize);
  });
}
