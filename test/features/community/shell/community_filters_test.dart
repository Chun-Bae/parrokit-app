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
    expect(at(const Duration(minutes: -1)), '마감 지남');
  });

  test('탭을 열면 걸러진 목록이 아니라 전체를 보여준다', () {
    // 질문 탭만 '답변 대기'로 열려서, 들어오자마자 채택이 끝난 질문이 빠진
    // 목록을 봤다(5차).
    expect(CommunityFilters.defaultBoard, '전체');
    expect(CommunityFilters.defaultQuestionStatus, '전체');
    expect(CommunityFilters.board, contains(CommunityFilters.defaultBoard));
    expect(CommunityFilters.questionStatus,
        contains(CommunityFilters.defaultQuestionStatus));
  });

  test('질문은 거르기와 정렬을 따로 고른다', () {
    // 전에는 다섯 칸 한 줄이라 '답변 대기'를 보면서 '공감 순'으로 볼 수
    // 없었다(5차).
    expect(CommunityFilters.questionStatus, ['전체', '답변 대기', '채택 완료']);
    expect(CommunityFilters.questionSort, ['최신 순', '공감 순', '오래된 순']);
    expect(CommunityFilters.defaultQuestionSort,
        CommunityFilters.questionSort.first);
  });
}
