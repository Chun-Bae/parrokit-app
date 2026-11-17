// 글쓰기 화면에서 '올리기'가 꺼져 있는 까닭.
//
// 게시판·질문·투표가 저마다 조건을 따로 적어 두고, 셋 다 꺼진 단추를 눌러도
// 아무 일이 없었다. 무엇이 빠졌는지 한 곳에서 정해 같은 말로 알린다(5차).

/// 올릴 때 쓰는 글귀. 꺼진 단추 아래 안내와 올리기 검사가 **같은 말**을
/// 쓰도록 여기 모은다(5차 433). 전에는 단추 아래는 '게시판을 골라 주세요',
/// 올리면 '주제를 골라 주세요'였다. 화면의 드롭다운과 고르기 시트는 둘 다
/// '주제'라고 부른다.
const String writeNeedsTitleMessage = '제목을 적어 주세요.';
const String writeNeedsContentMessage = '내용을 적어 주세요.';
const String writeNeedsTopicMessage = '주제를 골라 주세요.';

/// 투표 보기 수. 조건은 2개 미만이면 막는 것이라 '2개 이상'이 맞다.
/// 전에는 '2개 넘게'라 적어 3개부터인 것처럼 읽혔다(5차 433).
const String writeNeedsTwoOptionsMessage = '보기를 2개 이상 적어 주세요.';
const String writeNeedsFilledOptionsMessage = '빈 보기 칸을 채워 주세요.';

/// 태그 수·길이 제한을 넘겼을 때.
String writeTooManyTagsMessage(int max) => '태그는 $max개까지 넣을 수 있어요.';

/// 올릴 수 없는 까닭. 올릴 수 있으면 null.
///
/// [optionCount]·[filledOptionCount]는 투표에만 쓴다(없으면 따지지 않는다).
String? writeBlockedReason({
  required bool hasTitle,
  required bool hasContent,
  bool hasTopic = true,
  int? optionCount,
  int? filledOptionCount,
}) {
  if (!hasTitle) return writeNeedsTitleMessage;
  if (!hasContent) return writeNeedsContentMessage;
  if (!hasTopic) return writeNeedsTopicMessage;
  if (optionCount != null) {
    if (optionCount < 2) return writeNeedsTwoOptionsMessage;
    if ((filledOptionCount ?? optionCount) < optionCount) {
      return writeNeedsFilledOptionsMessage;
    }
  }
  return null;
}
