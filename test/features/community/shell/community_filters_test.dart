// 투표 필터 이름(5차): '완료'·'만료'는 글자가 비슷하고 '완료'의 뜻(내가 참여함)이
// 드러나지 않았다. 화면은 순서로 비교하므로 순서는 그대로여야 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';
import 'package:parrokit/features/community/vote/presentation/vote_screen.dart';

void main() {
  test('투표 필터는 랜덤·전체·참여함·마감 순서', () {
    expect(CommunityFilters.vote, ['랜덤', '전체', '참여함', '마감']);
    expect(CommunityFilters.defaultVote, CommunityFilters.vote.first);
  });

  test('투표 남은 시간은 마감으로 말하고 느낌표·0분이 없다', () {
    final now = DateTime(2026, 11, 13, 12);
    String at(Duration d) => voteRemainingLabel(now.add(d), now);
    expect(at(const Duration(days: 1, hours: 3)), '1일 뒤 마감');
    expect(at(const Duration(hours: 2, minutes: 5)), '2시간 5분 뒤 마감');
    expect(at(const Duration(hours: 2)), '2시간 뒤 마감');
    expect(at(const Duration(minutes: 7)), '7분 뒤 마감');
    expect(at(const Duration(seconds: 30)), '곧 마감');
    expect(at(const Duration(minutes: -1)), '투표 마감');
  });

  test('탭을 열면 걸러진 목록이 아니라 전체를 보여준다', () {
    // 질문 탭만 '답변 대기'로 열려서, 들어오자마자 채택이 끝난 질문이 빠진
    // 목록을 봤다. 칩이 가운데에 있어 걸러진 줄도 모른다(5차).
    expect(CommunityFilters.defaultBoard, '전체');
    expect(CommunityFilters.defaultQuestion, '전체');
    expect(CommunityFilters.board, contains(CommunityFilters.defaultBoard));
    expect(
        CommunityFilters.question, contains(CommunityFilters.defaultQuestion));
  });

  test('질문 필터는 거르기 셋과 정렬 둘이다', () {
    expect(CommunityFilters.question,
        ['전체', '채택 완료', '답변 대기', '공감 순', '오래된 순']);
  });
}
