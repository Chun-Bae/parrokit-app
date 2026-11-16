// 댓글·답글 입력칸 안내를 세 화면에서 같은 말로 쓴다(5차).
//
// 게시판 '댓글을 입력해주세요.', 투표 '댓글 남기기', 질문 '답글 남기기...'로
// 화면마다 달랐다. 질문만 '답글'이라 부르는 것은 화면 글('답글 1')과 같다.
//
// 214에서 게시판·투표는 답글을 쓰는 중이면 안내도 '답글…'로 바뀌게 했다.
// 그래서 두 화면은 글자 대신 commentInputHint를 쓴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/comment_input_text.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('입력칸 안내는 "…을 남겨 보세요" 꼴로 같다', () {
    expect(commentInputHint(replying: false), '댓글을 남겨 보세요');
    expect(commentInputHint(replying: true), '답글을 남겨 보세요');
    expect(
      _read(
          'lib/features/community/board/presentation/widgets/board_comment_input_bar.dart'),
      contains('hintText: commentInputHint('),
    );
    expect(
      _read('lib/features/community/vote/presentation/vote_view_screen.dart'),
      contains('hintText: commentInputHint('),
    );
    // 질문 화면은 220에서 '답변'과 '답글'을 나눴다. 질문에 바로 다는 것은
    // 답변, 답변에 다는 것은 답글이다.
    expect(
      _read(
          'lib/features/community/question/presentation/question_view_screen.dart'),
      contains('hintText: questionInputHint('),
    );
  });
}
