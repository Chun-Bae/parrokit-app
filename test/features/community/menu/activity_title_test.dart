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

  test('엄지(공감)와 하트(좋아요)를 이름으로도 가른다', () {
    // 글·질문·투표는 엄지 '공감', 댓글·답변은 하트 '좋아요'다(89d57b67).
    // 메뉴만 둘 다 '공감'이라 버튼 이름과 어긋났다(5차).
    for (final board in ['board', 'question', 'vote']) {
      final liked = communityActivityTitle(board, 'liked');
      final likedComment = communityActivityTitle(board, 'liked_comment');
      expect(liked, isNotNull, reason: board);
      expect(liked, startsWith('공감한'), reason: board);
      expect(likedComment, isNotNull, reason: board);
      expect(likedComment, startsWith('좋아요한'), reason: board);
    }
  });

  test('아이콘도 공감은 엄지, 좋아요는 하트다', () {
    for (final section in const CommunityMenuSectionFactory().build()) {
      for (final category in section.categories) {
        for (final item in category.items) {
          if (item.activityType == 'liked') {
            expect(item.iconKey, 'thumb_up', reason: item.title);
          }
          if (item.activityType == 'liked_comment') {
            expect(item.iconKey, 'favorite', reason: item.title);
          }
        }
      }
    }
  });
}
