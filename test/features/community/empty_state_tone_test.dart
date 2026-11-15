// 화면 말투를 '~어요'로 맞춘다(5차 UX 점검).
//
// 빈 화면과 확인 창은 사용자가 흔히 만나는 자리인데 '~습니다'가 섞여 있었다.
// 글만 바뀌므로 파일을 읽어 확인한다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// 사용자가 자주 만나는 화면들. 여기에는 '~습니다/~습니까'가 없어야 한다.
const _screens = [
  'lib/features/community/vote/presentation/vote_screen.dart',
  'lib/features/community/question/presentation/question_screen.dart',
  'lib/features/home/recent/presentation/widgets/empty_recent_view.dart',
  'lib/features/settings/more/presentation/sections/logout_section.dart',
  'lib/features/settings/more/presentation/sections/delete_account_section.dart',
  'lib/features/settings/more/presentation/profile_edit_screen.dart',
  'lib/features/auth/sign-up/sign_up_screen.dart',
  'lib/features/auth/onboarding/onboarding_screen.dart',
];

void main() {
  test("빈 화면과 확인 창에 '~습니다' 말투가 없다", () {
    final formal = RegExp(r"'[^']*(습니다|습니까)[^']*'");
    for (final path in _screens) {
      final found = formal.firstMatch(_code(path))?.group(0);
      expect(found, isNull, reason: '$path 에 남아 있다: $found');
    }
  });

  test('질문 빈 화면은 거르개에 따라 다른 말을 한다', () {
    final code = _code(
        'lib/features/community/question/presentation/question_screen.dart');
    // '전체'인데 "다른 조건을 골라 보라"고 하면 할 수 있는 일이 아니다.
    expect(code, contains("'첫 질문을 올려 보세요.'"));
    expect(code, contains("'고른 조건에 맞는 질문이 없어요.'"));
    expect(code, contains("'다른 조건을 골라 보거나 직접 질문해 보세요.'"));
  });

  test('투표 빈 화면 셋이 모두 같은 말투다', () {
    final code =
        _code('lib/features/community/vote/presentation/vote_screen.dart');
    expect(code, contains("'진행 중인 투표가 없어요.'"));
    expect(code, contains("'참여한 투표가 없어요.'"));
    expect(code, contains("'마감된 투표가 없어요.'"));
  });

  test('탈퇴 창은 되돌릴 수 없다는 것을 그대로 알린다', () {
    final code = _code(
        'lib/features/settings/more/presentation/sections/delete_account_section.dart');
    expect(code, contains('되돌릴 수 없어요'));
    expect(code, contains('정말 탈퇴할까요?'));
  });
}
