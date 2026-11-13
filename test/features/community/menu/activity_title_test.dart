// 내 활동 화면 제목은 메뉴에서 누른 줄과 같아야 한다(5차).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/menu/data/factories/community_menu_section_factory.dart';

void main() {
  test('메뉴의 모든 활동 줄이 같은 이름으로 화면 제목을 얻는다', () {
    for (final section in const CommunityMenuSectionFactory().build()) {
      for (final category in section.categories) {
        for (final item in category.items) {
          if (item.boardType == null || item.activityType == null) continue;
          expect(communityActivityTitle(item.boardType!, item.activityType!),
              item.title);
        }
      }
    }
  });

  test('질문 게시판 이름이 화면과 맞는다', () {
    expect(communityActivityTitle('question', 'written'), '작성한 질문');
    expect(communityActivityTitle('question', 'commented'), '작성한 답변');
    expect(communityActivityTitle('question', 'commented_reply'), '작성한 답글');
    expect(communityActivityTitle('board', 'unknown'), isNull);
  });
}
