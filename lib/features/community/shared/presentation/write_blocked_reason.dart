// 글쓰기 화면에서 '올리기'가 꺼져 있는 까닭.
//
// 게시판·질문·투표가 저마다 조건을 따로 적어 두고, 셋 다 꺼진 단추를 눌러도
// 아무 일이 없었다. 무엇이 빠졌는지 한 곳에서 정해 같은 말로 알린다(5차).

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
  if (!hasTitle) return '제목을 적어 주세요.';
  if (!hasContent) return '내용을 적어 주세요.';
  if (!hasTopic) return '게시판을 골라 주세요.';
  if (optionCount != null) {
    if (optionCount < 2) return '고를 보기를 2개 넘게 적어 주세요.';
    if ((filledOptionCount ?? optionCount) < optionCount) {
      return '빈 보기 칸을 채워 주세요.';
    }
  }
  return null;
}
