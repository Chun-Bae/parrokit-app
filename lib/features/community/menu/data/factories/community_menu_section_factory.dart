import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/features/community/menu/domain/entities/community_menu_entry.dart';

class CommunityMenuSectionFactory {
  const CommunityMenuSectionFactory();

  List<CommunityMenuSectionEntry> build() {
    return [
      CommunityMenuSectionEntry(
        title: '나의 활동',
        categories: [
          CommunityMenuCategoryEntry(
            // 탭 이름과 맞춘다(5차). 예전 이름은 '일반 게시판'.
            title: '게시판',
            items: _boardItems(),
          ),
          CommunityMenuCategoryEntry(
            title: '질문 게시판',
            items: _questionItems(),
          ),
          CommunityMenuCategoryEntry(
            title: '투표 게시판',
            items: _voteItems(),
          ),
        ],
      ),
      CommunityMenuSectionEntry(
        title: '커뮤니티 설정',
        categories: [
          CommunityMenuCategoryEntry(
            title: null,
            items: const [
              // 알림 설정 화면을 만들어 다시 넣었다(5차, 사용자 요청). 전에는
              // 갈 화면이 없어 눌러도 아무 일이 없었다.
              CommunityMenuEntry(
                title: '알림 설정',
                iconKey: 'notifications',
                colorKey: 'settings',
                routePath: AppRoutes.communityNotificationSettingsPath,
              ),
              CommunityMenuEntry(
                title: '차단 사용자 관리',
                iconKey: 'shield',
                colorKey: 'settings',
                routePath: AppRoutes.communityBlockedUsersPath,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<CommunityMenuEntry> _boardItems() {
    return const [
      CommunityMenuEntry(title: '작성한 글', iconKey: 'article', colorKey: 'board', boardType: 'board', activityType: 'written'),
      CommunityMenuEntry(title: '작성한 댓글', iconKey: 'chat_bubble', colorKey: 'board', boardType: 'board', activityType: 'commented'),
      CommunityMenuEntry(title: '공감한 글', iconKey: 'thumb_up', colorKey: 'board', boardType: 'board', activityType: 'liked'),
      CommunityMenuEntry(title: '공감한 댓글', iconKey: 'favorite', colorKey: 'board', boardType: 'board', activityType: 'liked_comment'),
      CommunityMenuEntry(title: '스크랩', iconKey: 'bookmark', colorKey: 'board', boardType: 'board', activityType: 'scraped'),
    ];
  }

  List<CommunityMenuEntry> _questionItems() {
    return const [
      CommunityMenuEntry(title: '작성한 질문', iconKey: 'help', colorKey: 'question', boardType: 'question', activityType: 'written'),
      CommunityMenuEntry(title: '작성한 답변', iconKey: 'forum', colorKey: 'question', boardType: 'question', activityType: 'commented'),
      // 내가 답변 아래에 단 답글이다. 예전 '답변에 달린 댓글'은 남이 내 답변에 단 댓글처럼
      // 읽혔다(5차). 질문 상세의 '답글 쓰기'와 같은 말.
      CommunityMenuEntry(title: '작성한 답글', iconKey: 'chat', colorKey: 'question', boardType: 'question', activityType: 'commented_reply'),
      CommunityMenuEntry(title: '공감한 질문', iconKey: 'thumb_up', colorKey: 'question', boardType: 'question', activityType: 'liked'),
      CommunityMenuEntry(title: '공감한 답변 및 댓글', iconKey: 'favorite', colorKey: 'question', boardType: 'question', activityType: 'liked_comment'),
      CommunityMenuEntry(title: '스크랩', iconKey: 'bookmark', colorKey: 'question', boardType: 'question', activityType: 'scraped'),
    ];
  }

  List<CommunityMenuEntry> _voteItems() {
    return const [
      CommunityMenuEntry(title: '참여한 투표', iconKey: 'how_to_vote', colorKey: 'vote', boardType: 'vote', activityType: 'written'),
      CommunityMenuEntry(title: '게시한 투표', iconKey: 'campaign', colorKey: 'vote', boardType: 'vote', activityType: 'written_posted'),
      CommunityMenuEntry(title: '작성한 댓글', iconKey: 'chat', colorKey: 'vote', boardType: 'vote', activityType: 'commented'),
      CommunityMenuEntry(title: '공감한 투표', iconKey: 'thumb_up', colorKey: 'vote', boardType: 'vote', activityType: 'liked'),
      CommunityMenuEntry(title: '공감한 댓글', iconKey: 'favorite', colorKey: 'vote', boardType: 'vote', activityType: 'liked_comment'),
      CommunityMenuEntry(title: '스크랩', iconKey: 'bookmark', colorKey: 'vote', boardType: 'vote', activityType: 'scraped'),
    ];
  }
}

/// 내 활동 목록 화면 제목에 쓸 이름. 메뉴에서 누른 줄과 같은 이름을 돌려준다(5차).
/// 예전엔 활동 화면이 따로 이름을 지어 '작성한 질문'을 누르면 '작성한 질문/답변',
/// '작성한 답변'은 '작성한 댓글', 답글은 '활동'으로 나왔다. 메뉴에 없으면 null.
String? communityActivityTitle(String boardType, String activityType) {
  for (final section in const CommunityMenuSectionFactory().build()) {
    for (final category in section.categories) {
      for (final item in category.items) {
        if (item.boardType == boardType && item.activityType == activityType) {
          return item.title;
        }
      }
    }
  }
  return null;
}
