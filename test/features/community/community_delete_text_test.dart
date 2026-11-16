// 지우기 안내는 한 곳에서 오고 조사도 맞춘다(5차 327).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/community_delete_text.dart';

const screens = [
  'lib/features/community/vote/presentation/vote_view_screen.dart',
  'lib/features/community/board/presentation/handlers/board_options_handler.dart',
  'lib/features/community/question/presentation/question_view_screen.dart',
];

void main() {
  test('받침에 맞춰 조사를 고른다', () {
    expect(postDeletedMessage('글'), '글을 지웠어요.');
    expect(postDeletedMessage('질문'), '질문을 지웠어요.');
    expect(postDeletedMessage('투표'), '투표를 지웠어요.');
  });

  test('말투는 앱의 다른 곳과 같다', () {
    expect(commentDeletedMessage, '댓글을 지웠어요.');
    expect(deleteFailedMessage, contains('지우지 못했어요'));
    for (final message in [commentDeletedMessage, deleteFailedMessage]) {
      expect(message.contains('습니다'), isFalse, reason: message);
    }
  });

  test('세 화면이 같은 말을 가져다 쓴다', () {
    for (final path in screens) {
      final code = File(path).readAsStringSync();
      expect(code, contains('commentDeletedMessage'), reason: path);
      expect(code, contains('deleteFailedMessage'), reason: path);
      expect(code.contains("'삭제에 실패했습니다.'"), isFalse, reason: path);
      expect(code.contains("'댓글이 삭제되었습니다.'"), isFalse, reason: path);
    }
  });
}
