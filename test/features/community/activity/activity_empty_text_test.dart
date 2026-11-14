// 내 활동 빈 화면 문구(5차). 어느 줄로 들어왔는지 말하고 앱 말투를 쓴다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/korean_josa.dart';
import 'package:parrokit/features/community/menu/data/factories/community_menu_section_factory.dart';

String emptyTextFor(String boardType, String activityType) {
  final title = communityActivityTitle(boardType, activityType);
  if (title == null || title.isEmpty) return '아직 활동이 없어요.';
  return '아직 ${iGa(title)} 없어요.';
}

void main() {
  test('메뉴에서 누른 줄 이름을 그대로 쓴다', () {
    expect(emptyTextFor('board', 'written'), '아직 작성한 글이 없어요.');
    expect(emptyTextFor('question', 'commented'), '아직 작성한 답변이 없어요.');
    expect(emptyTextFor('vote', 'written'), startsWith('아직 참여한 투표'));
  });

  test('조사를 받침에 맞춰 붙인다', () {
    expect(emptyTextFor('board', 'scraped'), contains('스크랩이 없어요'));
    expect(emptyTextFor('board', 'liked_comment'), contains('댓글이 없어요'));
  });

  test('모르는 줄이면 뭉뚱그려 말하되 말투는 같다', () {
    expect(emptyTextFor('board', 'unknown'), '아직 활동이 없어요.');
    expect(emptyTextFor('board', 'unknown'), endsWith('없어요.'));
  });

  test('메뉴의 모든 줄이 자연스러운 빈 문구를 만든다', () {
    for (final section in const CommunityMenuSectionFactory().build()) {
      for (final category in section.categories) {
        for (final item in category.items) {
          if (item.boardType == null || item.activityType == null) continue;
          final text = emptyTextFor(item.boardType!, item.activityType!);
          expect(text, startsWith('아직 '), reason: item.title);
          expect(text, endsWith('없어요.'), reason: item.title);
          // '(이)가'처럼 두 가지를 함께 쓰는 꼴이 나오면 안 된다.
          expect(text.contains('('), isFalse, reason: text);
        }
      }
    }
  });
}
