// 댓글·답글 입력칸 안내를 세 화면에서 같은 말로 쓴다(5차).
//
// 게시판 '댓글을 입력해주세요.', 투표 '댓글 남기기', 질문 '답글 남기기...'로
// 화면마다 달랐다. 질문만 '답글'이라 부르는 것은 화면 글('답글 1')과 같다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('입력칸 안내는 "…을 남겨 보세요" 꼴로 같다', () {
    expect(
      _read('lib/features/community/board/presentation/widgets/board_comment_input_bar.dart'),
      contains("hintText: '댓글을 남겨 보세요'"),
    );
    expect(
      _read('lib/features/community/vote/presentation/vote_view_screen.dart'),
      contains("hintText: '댓글을 남겨 보세요'"),
    );
    expect(
      _read('lib/features/community/question/presentation/question_view_screen.dart'),
      contains("hintText: '답글을 남겨 보세요'"),
    );
  });
}
