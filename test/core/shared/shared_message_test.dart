// 같은 말을 여러 화면에 적어 두지 않는다(5차 317).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/network_error.dart';
import 'package:parrokit/core/shared/utils/nickname_rule.dart';

Iterable<File> dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('닉네임 안내는 한 곳에서만 적는다', () {
    // 온보딩·회원가입·프로필 수정 세 곳에 같은 글이 따로 있었다.
    for (final message in [
      nicknameNeededMessage,
      nicknameAvailableMessage,
      nicknameTakenMessage,
    ]) {
      final hits = dartFiles('lib')
          .where((f) => !f.path.endsWith('nickname_rule.dart'))
          .where((f) => f.readAsStringSync().contains("'$message'"))
          .map((f) => f.path)
          .toList();
      expect(hits, isEmpty, reason: message);
    }
  });

  test('닉네임 안내도 앱의 말투를 따른다', () {
    expect(nicknameNeededMessage, contains('적어 주세요'));
    expect(nicknameNeededMessage.contains('입력해주세요'), isFalse);
  });

  test('세 화면이 그 말을 가져다 쓴다', () {
    for (final path in [
      'lib/features/auth/onboarding/onboarding_screen.dart',
      'lib/features/auth/sign-up/sign_up_screen.dart',
      'lib/features/settings/more/presentation/profile_edit_screen.dart',
    ]) {
      final code = File(path).readAsStringSync();
      expect(code, contains('nicknameNeededMessage'), reason: path);
    }
  });

  test('인터넷이 끊겼다는 말도 한 곳에서만 적는다', () {
    final hits = dartFiles('lib')
        .where((f) => !f.path.endsWith('network_error.dart'))
        .where((f) => f.readAsStringSync().contains("'$offlineMessage'"))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty);
    expect(offlineMessage, contains('인터넷'));
  });
}
