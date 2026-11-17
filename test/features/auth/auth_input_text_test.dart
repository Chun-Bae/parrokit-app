// 로그인·가입·비밀번호 찾기가 같은 입력 안내를 쓴다(5차 415).
//
// 세 화면이 같은 말을 각자 적고 있었다. 같은 화면 안에서도 서버 오류를
// 옮긴 글은 '이메일 형식이 올바르지 않아요.'인데 입력칸 아래에는
// '올바른 이메일 형식이 아닙니다.'가 떴다. '입력해 주세요'도 앱의 다른
// 곳('적어 주세요')과 달랐다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/auth/auth_input_text.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

const _screens = [
  'lib/features/auth/sign-up/sign_up_screen.dart',
  'lib/features/auth/sign-in/sign_in_screen.dart',
  'lib/features/auth/find-pw/find_pw_screen.dart',
];

void main() {
  test('앱 말투로 적는다', () {
    for (final text in [
      emailNeededMessage,
      passwordNeededMessage,
      passwordAgainNeededMessage,
    ]) {
      expect(text, contains('적어 주세요'));
      expect(text, isNot(contains('입력')));
    }
    expect(emailInvalidMessage, '이메일 형식이 올바르지 않아요.');
    expect(findPasswordGuide, isNot(contains('니다')));
  });

  test('세 화면이 손으로 적지 않고 가져다 쓴다', () {
    for (final path in _screens) {
      final code = _code(path);
      expect(code, contains('auth_input_text.dart'), reason: path);
      // 화면마다 따로 적던 말들.
      expect(code, isNot(contains("'이메일을 입력해 주세요.'")), reason: path);
      expect(code, isNot(contains("'비밀번호를 입력해 주세요.'")), reason: path);
      expect(code, isNot(contains("'올바른 이메일 형식이 아닙니다.'")), reason: path);
    }
  });

  test('다른 화면의 입력 안내도 같은 말투다', () {
    final profile = _code(
        'lib/features/settings/more/presentation/profile_edit_screen.dart');
    expect(profile, isNot(contains('입력하세요')));
    final exchange =
        _code('lib/features/settings/more/presentation/exchange_screen.dart');
    expect(exchange, isNot(contains('입력해 주세요')));
  });
}
