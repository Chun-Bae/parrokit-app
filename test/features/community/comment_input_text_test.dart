// 답글을 쓰는 중이면 입력줄도 '답글'이라고 불러야 한다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/comment_input_text.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('댓글과 답글을 구분해 부른다', () {
    expect(commentInputHint(replying: false), '댓글을 남겨 보세요');
    expect(commentInputHint(replying: true), '답글을 남겨 보세요');
    expect(commentSendTooltip(replying: false), '댓글 보내기');
    expect(commentSendTooltip(replying: true), '답글 보내기');
  });

  test('답글 대상 안내는 띄어쓰기까지 한 가지로 적는다', () {
    expect(replyingToLabel('봄배'), '봄배님에게 답글 남기는 중');
    // 예전에는 투표 화면만 '봄배 님에게'처럼 띄어 썼다.
    expect(replyingToLabel('봄배'), isNot(contains(' 님에게')));
  });

  test('게시판·투표 입력줄이 같은 글을 쓴다', () {
    const paths = [
      'lib/features/community/board/presentation/widgets/board_comment_input_bar.dart',
      'lib/features/community/vote/presentation/vote_view_screen.dart',
    ];
    for (final path in paths) {
      final code = _code(path);
      expect(code, contains('commentInputHint('), reason: path);
      expect(code, contains('commentSendTooltip('), reason: path);
      expect(code, contains('replyingToLabel('), reason: path);
      // 같은 말을 손으로 또 적지 않는다.
      expect(code, isNot(contains("hintText: '댓글을 남겨 보세요'")), reason: path);
      expect(code, isNot(contains('답글 남기는 중\'')), reason: path);
    }
  });
}
