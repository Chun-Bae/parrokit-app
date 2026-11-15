// 투표 확인 창이 다른 확인 창과 같은 말투인지 본다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/vote/presentation/vote_confirm_text.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('제목은 하는 일, 본문은 앱 말투로 적는다', () {
    expect(voteConfirmTitle, '투표하기');
    final message = voteConfirmMessage('5문장');
    expect(message, contains("'5문장'에 투표할까요?"));
    expect(message, contains('바꿀 수 없어요'));
    expect(message, isNot(contains('습니다')));
    expect(message, isNot(contains('항목에')));
  });

  test('되돌릴 수 없다는 것을 먼저 알린다', () {
    // 글·댓글·알림 지우기 확인과 같은 두 줄 꼴.
    expect(voteConfirmMessage('5문장').split('\n').length, 2);
  });

  test('투표 화면이 그 글을 쓴다', () {
    final code = _code('lib/features/community/vote/presentation/vote_screen.dart');
    expect(code, contains('voteConfirmTitle'));
    expect(code, contains('voteConfirmMessage('));
    expect(code, isNot(contains('투표하시겠습니까')));
    expect(code, isNot(contains('수정할 수 없습니다')));
  });
}
