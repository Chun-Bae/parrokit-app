class CommunityFilters {
  static const List<String> board = ['전체', '자유', '추천해요', '꿀팁', '일상', '분석'];
  // '전체'는 상태로 거르지 않고 읽어 온 질문을 모두 보여준다.
  static const List<String> question = [
    '전체',
    '채택 완료',
    '답변 대기중',
    '화제의 질문',
    '오래된 질문',
  ];
  // '참여함'은 내가 투표한 글, '마감'은 기간이 끝난 글. 예전 이름 '완료'·'만료'는
  // 글자가 비슷하고 '완료'가 무엇이 끝난 건지 알 수 없었다(5차). 화면은 순서(index)로
  // 비교하므로 이름만 바뀐다.
  static const List<String> vote = ['랜덤', '전체', '참여함', '마감'];

  static const String defaultBoard = '전체';
  static const String defaultQuestion = '답변 대기중';
  static const String defaultVote = '랜덤';

  const CommunityFilters._();
}
