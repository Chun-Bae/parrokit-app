// 질문 화면이 쓰는 말. '답변'과 '답글'을 섞어 써서 정리한 것(5차).
//
// 질문에 바로 달리는 글은 **답변**이다(채택·보상·커뮤니티 메뉴가 그렇게
// 부른다). 그 답변에 달리는 글이 **답글**이다. 전에는 머리말이 '답글 3',
// 빈 상태는 '아직 답변이 없습니다', 메뉴는 '작성한 답변'·'작성한 답글'로
// 제각각이었다.

/// 머리말. 질문에 바로 달린 답변 수만 센다(답글은 각 답변 아래 붙는다).
String questionAnswerCountLabel(int answerCount) => '답변 $answerCount';

/// 아직 아무도 답하지 않았을 때.
const String questionNoAnswersMessage = '아직 답변이 없어요.\n첫 답변을 남겨 주세요.';

/// 차단한 사람의 답변 자리.
const String questionBlockedAnswerMessage = '차단한 사람의 답변이에요.';

/// 질문 머리의 버튼. 질문에 바로 답을 다는 자리다.
const String questionWriteAnswerLabel = '답변 쓰기';

/// 입력칸 안내. 답글을 쓰는 중이면 '답글', 아니면 '답변'.
String questionInputHint({required bool replying}) =>
    replying ? '답글을 남겨 보세요' : '답변을 남겨 보세요';

/// 채택 확인 창.
const String questionAcceptTitle = '답변 채택';

String questionAcceptMessage(int rewardCrackers) =>
    '이 답변을 채택할까요?\n채택하면 크래커 $rewardCrackers개를 보내요.';
