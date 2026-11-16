// 커뮤니티 화면 글은 앱 말투('~어요')를 쓴다(5차 375).
//
// 327에서 지우기 안내를 모았고, 310에서 예외 글을 사람 말로 바꿨다. 남아
// 있던 것은 질문 상세의 채택·답글 안내, 차단 묻는 창, 게시판 빈 화면이었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 화면 파일에서 사람에게 보이는 글만 본다(주석은 뺀다).
Iterable<String> _visibleLines(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .where((line) => line.contains("'") || line.contains('"'));

void main() {
  test('커뮤니티 화면 글에 ~습니다/~습니까/~입니다가 없다', () {
    final offenders = <String>[];
    for (final dir in [
      Directory('lib/features/community'),
    ]) {
      for (final file in dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.path.contains('/presentation/'))
          // 서버에 적어 두는 글(지운 댓글의 content)은 예전 값과 같아야 한다.
          .where((f) => !f.path.endsWith('community_provider_comment.dart'))) {
        for (final line in _visibleLines(file)) {
          if (line.contains('습니다') ||
              line.contains('습니까') ||
              line.contains('입니다')) {
            offenders.add('${file.path}: ${line.trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('바뀐 안내는 할 수 있는 말로 적는다', () {
    final question = File(
            'lib/features/community/question/presentation/question_view_screen.dart')
        .readAsStringSync();
    expect(question, contains('답변을 채택했어요!'));
    expect(question, contains('마감 기한이 지난 질문이에요.'));

    final block = File(
            'lib/features/community/shared/presentation/widgets/community_block_actions.dart')
        .readAsStringSync();
    expect(block, contains('차단할까요?'));

    // 지운 댓글·차단한 사람의 댓글 자리도 같은 말투로(5차 375).
    // 403에서 글귀를 community_delete_text 한 곳으로 모았다.
    final texts = File(
            'lib/features/community/shared/presentation/community_delete_text.dart')
        .readAsStringSync();
    expect(texts, contains('지운 댓글이에요.'));
    expect(texts, contains('차단한 사람의 댓글이에요.'));

    for (final path in const [
      'lib/features/community/board/presentation/widgets/board_comment_item.dart',
      'lib/features/community/vote/presentation/vote_view_screen.dart',
      // 질문 화면은 지운 답변을 아예 가리지 않고 있었다(5차 404).
      'lib/features/community/question/presentation/question_view_screen.dart',
    ]) {
      final code = File(path)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, contains('deletedCommentText'), reason: path);
      // 지운 댓글에는 이름을 적지 않는다(5차 403).
      expect(code, isNot(contains("'(삭제됨)'")), reason: path);
      expect(code, contains('if (!isDeleted)'), reason: path);
    }
    for (final path in const [
      'lib/features/community/board/presentation/widgets/board_comment_item.dart',
      'lib/features/community/vote/presentation/vote_view_screen.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('blockedCommentText'),
          reason: path);
    }
  });
}
