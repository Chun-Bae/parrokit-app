// 댓글 보내기가 꺼진 까닭(5차 312). 화면마다 같은 말을 쓴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/comment_input_text.dart';
import 'package:parrokit/features/community/shared/presentation/community_error_text.dart';

String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('적은 것이 없으면 그렇게 말하고, 답글이면 답글이라고 부른다', () {
    expect(commentBlockedReason(hasText: false, replying: false),
        '댓글을 적어야 보낼 수 있어요.');
    expect(commentBlockedReason(hasText: false, replying: true),
        '답글을 적어야 보낼 수 있어요.');
    expect(commentBlockedReason(hasText: true, replying: false), isNull);
  });

  test('게시판·투표 상세 모두 이 말을 쓴다', () {
    for (final path in [
      'lib/features/community/board/presentation/board_view_screen.dart',
      'lib/features/community/vote/presentation/vote_view_screen.dart',
    ]) {
      final code = _flat(File(path).readAsStringSync());
      expect(code, contains('commentBlockedReason('), reason: path);
    }
    // 입력줄 위젯은 꺼져 있어도 눌리게 둔다.
    final bar = _flat(File(
            'lib/features/community/board/presentation/widgets/board_comment_input_bar.dart')
        .readAsStringSync());
    expect(bar, contains('onPressed: canSubmit ? onSubmit : onBlocked'));
  });

  test('로그인 안내는 커뮤니티 전체가 한 말을 쓴다', () {
    // 전에는 '로그인이 필요해요.'와 '로그인하고 다시 해 주세요.'가 섞여 있었다.
    expect(communityLoginRequiredText, '로그인하고 다시 해 주세요.');
    final hits = <String>[];
    for (final file in Directory('lib/features/community')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final code = file.readAsStringSync();
      if (code.contains("'로그인이 필요해요.'") &&
          !file.path.endsWith('community_error_text.dart')) {
        hits.add(file.path);
      }
    }
    expect(hits, isEmpty);
  });
}
