// 질문 상세 버튼 이름은 메뉴·내 활동과 같아야 한다(5차).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/menu/data/factories/community_menu_section_factory.dart';

void main() {
  test('메뉴가 질문 공감을 부르는 이름과 버튼 이름이 같은 말을 쓴다', () {
    // 버튼은 '공감', 메뉴는 '공감한 질문'. 전에는 버튼만 '유용해요'였다.
    const buttonLabel = '공감';
    final menuTitle = communityActivityTitle('question', 'liked');
    expect(menuTitle, isNotNull);
    expect(menuTitle, startsWith(buttonLabel));
  });

  test('댓글 좋아요는 공감과 다른 말을 쓴다(엄지와 하트)', () {
    expect(communityActivityTitle('question', 'liked_comment'),
        startsWith('좋아요한'));
  });
}
