class CommunityFilters {
  static const List<String> board = ['전체', '자유', '추천해요', '꿀팁', '일상', '분석'];
  // '전체'는 상태로 거르지 않고 읽어 온 질문을 모두 보여준다.
  // 다섯 칸이라 짧게 쓴다. 뒤의 둘은 거르지 않고 순서만 바꾸므로 '…순'(5차).
  // 예전 이름: 답변 대기중·화제의 질문·오래된 질문. 저장하지 않는 값이다.
  static const List<String> question = [
    '전체',
    '채택 완료',
    '답변 대기',
    '공감 순',
    '오래된 순',
  ];
  // '참여함'은 내가 투표한 글, '마감'은 기간이 끝난 글. 예전 이름 '완료'·'만료'는
  // 글자가 비슷하고 '완료'가 무엇이 끝난 건지 알 수 없었다(5차). 화면은 순서(index)로
  // 비교하므로 이름만 바뀐다.
  static const List<String> vote = ['랜덤', '전체', '참여함', '마감'];

  static const String defaultBoard = '전체';
  // 질문 탭만 '답변 대기'로 열려서, 들어오자마자 채택이 끝난 질문이 빠진
  // 목록을 봤다. 칩이 가운데에 있어 걸러진 줄도 모른다. 게시판과 같이
  // '전체'로 연다(5차).
  static const String defaultQuestion = '전체';
  // 투표의 '랜덤'은 거르는 게 아니라 순서를 섞어 둘러보게 하는 것이라 둔다.
  static const String defaultVote = '랜덤';

  const CommunityFilters._();
}
