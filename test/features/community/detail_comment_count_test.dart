// 글 상세의 '댓글 N'·'답글 N'은 지금 불러온 목록을 세야 한다.
//
// 질문 상세만 서버에 적힌 수(commentCount)를 썼다. 가짜 커뮤니티에서
// '답글 1'이라고 쓰고 아래에 답글 셋이 보였다. 서버 카운터가 어긋나면
// 실제 앱에서도 같은 일이 난다(5차).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('질문 상세는 불러온 답변 수를 센다', () {
    final code =
        _code('lib/features/community/question/presentation/question_view_screen.dart');
    // 219에서 머리말을 '답변 N'으로 바꿨다. 세는 것은 질문에 바로 달린
    // 답변뿐이고(답글은 답변 아래), 서버 카운터는 쓰지 않는다.
    expect(code, contains('questionAnswerCountLabel('));
    expect(code, contains('.where((c) => c.parentId == null)'));
    expect(code, isNot(contains("'답글 \${question.commentCount}'")));
    expect(code, isNot(contains("'답변 \${question.commentCount}'")));
  });

  test('게시판·투표 상세도 목록을 센다', () {
    expect(
      _code('lib/features/community/board/presentation/sections/board_comments_section.dart'),
      contains("'댓글 \${comments.length}'"),
    );
    expect(
      _code('lib/features/community/vote/presentation/vote_view_screen.dart'),
      contains("'댓글 \${provider.currentPostComments.length}'"),
    );
  });
}
