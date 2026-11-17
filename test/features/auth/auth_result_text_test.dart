// 로그인·가입·비밀번호 찾기의 결과 안내도 한 곳에서 나온다(5차 416).
//
// 로그인 화면에만 '~습니다' 열네 곳이 남아 있었고, 소셜 로그인 넷이
// 성공·실패 글을 각자 적어 같은 문장이 여덟 번 되풀이됐다. 거기에 더해
// 세 화면이 'too-many-requests'를 직접 받아 적고 있었는데, 그 코드는
// userErrorMessage가 이미 같은 문장으로 옮긴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/auth/auth_result_text.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

const _screens = [
  'lib/features/auth/sign-in/sign_in_screen.dart',
  'lib/features/auth/sign-up/sign_up_screen.dart',
  'lib/features/auth/find-pw/find_pw_screen.dart',
];

void main() {
  test('방법 이름을 넣어 한 문장으로 만든다', () {
    expect(signedInMessage(), '로그인했어요.');
    expect(signedInMessage('구글'), '구글로 로그인했어요.');
    expect(signInFailedMessage('카카오'), startsWith('카카오 로그인을 마치지 못했어요.'));
    for (final text in [
      signedInMessage(),
      signedInMessage('애플'),
      signInFailedMessage(),
      signInFailedMessage('네이버'),
      signUpFailedMessage,
      resetMailSentMessage,
      resetMailFailedMessage,
    ]) {
      expect(text, isNot(contains('습니다')));
      expect(text, isNot(contains('오류')));
    }
  });

  test('세 화면에 예전 말투와 베낀 글이 남지 않았다', () {
    for (final path in _screens) {
      final code = _code(path);
      expect(code, isNot(contains('습니다')), reason: path);
      // userErrorMessage가 이미 옮기는 코드를 또 받아 적지 않는다.
      expect(code, isNot(contains("case 'too-many-requests'")), reason: path);
      expect(code, isNot(contains("'요청이 너무 많아요")), reason: path);
    }
  });

  test('목록 더 보기 단추도 한 이름을 쓴다', () {
    const paths = [
      'lib/features/community/vote/presentation/vote_screen.dart',
      'lib/features/community/board/presentation/board_screen.dart',
      'lib/features/community/question/presentation/question_screen.dart',
    ];
    for (final path in paths) {
      final code = _code(path);
      expect(code, contains('loadOlderPostsLabel'), reason: path);
      expect(code, isNot(contains("'이전 글 더 보기'")), reason: path);
    }
  });
}
