// 차단 관련 말이 화면마다 다르지 않아야 한다(5차 408).
//
// 차단 목록 화면과 글·댓글 옵션의 '차단'이 각자 글을 적고 있었다. 실패
// 안내가 '차단에 실패했어요.'(예전 말투)였고, 목록의 이름 기본값도
// '이름 없음'이라 다른 화면('알 수 없음')과 달랐다. 메뉴 줄은
// '차단 사용자 관리'인데 화면 제목도 같은 말이어야 어디로 왔는지 안다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/community_block_text.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('실패 안내는 지우기 실패와 같은 결로 적는다', () {
    expect(blockFailedMessage, '차단하지 못했어요. 잠시 뒤 다시 해 주세요.');
    expect(unblockFailedMessage, '차단을 풀지 못했어요. 잠시 뒤 다시 해 주세요.');
    // '~에 실패했어요'는 앱이 쓰지 않는 말이다.
    for (final text in [
      blockFailedMessage,
      unblockFailedMessage,
      blockedMessage,
      unblockedMessage,
      blockSelfMessage,
      unblockLabel,
      blockedUsersTitle,
    ]) {
      expect(text, isNot(contains('실패')));
      expect(text, isNot(contains('해제')));
    }
  });

  test('나를 차단하려 하면 무엇이 안 되는지 말한다', () {
    expect(blockSelfMessage, contains('차단할 수 없어요'));
  });

  test('메뉴 줄과 화면 제목, 세 파일이 같은 말을 쓴다', () {
    const paths = [
      'lib/features/community/block/presentation/blocked_users_screen.dart',
      'lib/features/community/shared/presentation/widgets/community_block_actions.dart',
      'lib/features/community/menu/data/factories/community_menu_section_factory.dart',
    ];
    for (final path in paths) {
      final code = _code(path);
      expect(code, isNot(contains("'차단에 실패했어요.'")), reason: path);
      expect(code, isNot(contains("'차단 사용자 관리'")), reason: path);
      expect(code, isNot(contains("'이름 없음'")), reason: path);
    }
  });
}
