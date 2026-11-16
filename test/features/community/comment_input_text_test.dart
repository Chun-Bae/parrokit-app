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

  test('못 올렸을 때 알리는 말도 댓글·답글을 가린다(5차 398)', () {
    expect(commentSendFailedText(replying: false), '댓글을 올리지 못했어요. 다시 해 주세요.');
    expect(commentSendFailedText(replying: true), '답글을 올리지 못했어요. 다시 해 주세요.');
  });

  test('세 화면이 같은 실패 안내와 같은 이름 기본값을 쓴다(5차 398)', () {
    const paths = [
      'lib/features/community/board/presentation/board_view_screen.dart',
      'lib/features/community/question/presentation/question_view_screen.dart',
      'lib/features/community/vote/presentation/vote_view_screen.dart',
    ];
    for (final path in paths) {
      final code = _code(path);
      expect(code, contains('commentSendFailedText('), reason: path);
      expect(code, contains('commentUnknownNickname'), reason: path);
      // 화면마다 손으로 적던 말들. '댓글 등록 실패'는 내부 말이었다.
      expect(code, isNot(contains("'댓글 등록 실패'")), reason: path);
      expect(code, isNot(contains("?? '익명'")), reason: path);
      // 닉네임이 없다고 이름 없이 올리지 않는다.
      expect(code, isNot(contains("displayName ?? ''")), reason: path);
    }
  });

  test('답글을 쓰는 중이었는지 보내기 전에 잡아 둔다', () {
    const paths = [
      'lib/features/community/board/presentation/board_view_screen.dart',
      'lib/features/community/vote/presentation/vote_view_screen.dart',
    ];
    for (final path in paths) {
      final code = _code(path);
      expect(code, contains('final replying = provider.replyingTo != null;'),
          reason: path);
      expect(code, isNot(contains('commentSendFailedText(replying: false)')),
          reason: path);
    }
  });
}
