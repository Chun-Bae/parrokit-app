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
  static const List<String> vote = ['랜덤', '전체', '완료', '만료'];

  static const String defaultBoard = '전체';
  static const String defaultQuestion = '답변 대기중';
  static const String defaultVote = '랜덤';

  const CommunityFilters._();
}
