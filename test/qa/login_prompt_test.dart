// 로그인하라고 할 때는 갈 길도 함께 준다(5차 439).
//
// 알림 설정 화면은 '로그인하면 알림을 설정할 수 있어요.'라고만 적고
// 끝냈다. 거기서 할 수 있는 일이 없어 되돌아 나가는 수밖에 없었다.
// 안내 꼴도 '로그인 후 …', '로그인하면 …', '로그인하고 …'로 갈렸다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_share_text.dart';
import 'package:parrokit/core/shared/utils/login_prompt_text.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('안내 꼴을 하나로 맞춘다', () {
    expect(loginToUse('알림을 설정할'), '로그인하면 알림을 설정할 수 있어요.');
    expect(likeNeedsLoginMessage, startsWith('로그인하면'));
    expect(sentenceShareNeedsLogin, startsWith('로그인하면'));
  });

  test('알림 설정 화면이 로그인으로 보내 준다', () {
    final code = _code(
        'lib/features/community/notification/presentation/notification_settings_screen.dart');
    expect(code, contains('goToSignInLabel'));
    expect(code, contains('goNamed(AppRoutes.signIn)'));
    // 안내만 적고 끝내지 않는다.
    expect(code, isNot(contains("_Message('로그인하면")));
  });

  test("'로그인 후'라는 꼴이 남아 있지 않다", () {
    final offenders = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      for (final line in e
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))) {
        if (line.contains("'") && line.contains('로그인 후')) {
          offenders.add(e.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
