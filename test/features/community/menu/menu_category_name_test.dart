// 커뮤니티 메뉴의 묶음 이름은 탭 이름과 같아야 한다(5차).
//
// 탭은 '게시판·질문·투표'인데 메뉴는 '게시판·질문 게시판·투표 게시판'이라,
// 한 화면 안에서 '게시판'이 두 뜻으로 읽혔다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/menu/data/factories/community_menu_section_factory.dart';

void main() {
  test("'나의 활동' 묶음 이름이 탭 이름과 같다", () {
    final sections = const CommunityMenuSectionFactory().build();
    final activity = sections.firstWhere((s) => s.title == '나의 활동');
    final names = activity.categories.map((c) => c.title).toList();
    expect(names, ['게시판', '질문', '투표']);

    // 탭 쪽도 같은 말인지 함께 본다.
    final shell = File(
      'lib/features/community/shell/presentation/community_shell_screen.dart',
    ).readAsStringSync();
    for (final name in names) {
      expect(shell.contains("Tab(text: '$name')"), isTrue, reason: name);
    }
  });

  test('메뉴 줄 이름에 문어체 "및"을 쓰지 않는다', () {
    for (final section in const CommunityMenuSectionFactory().build()) {
      for (final category in section.categories) {
        for (final item in category.items) {
          expect(item.title.contains(' 및 '), isFalse, reason: item.title);
        }
      }
    }
  });
}
