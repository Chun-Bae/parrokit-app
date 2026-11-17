// 자주 쓰는 실패 안내(5차 417).
//
// 같은 문장이 화면마다 손으로 적혀 있었다('저장하지 못했어요. 다시 시도해
// 주세요.'는 세 파일, '처리하지 못했어요...'도 세 파일). 한 곳만 다듬으면
// 나머지는 예전 말로 남아, 이번 주 내내 고쳐 온 어긋남이 다시 생긴다.
// 말은 지금 쓰던 것을 그대로 옮겨 적었다.

/// 무언가를 저장하지 못했을 때.
const String saveFailedMessage = '저장하지 못했어요. 다시 시도해 주세요.';

/// 문장을 저장하지 못했을 때(무엇을 저장하려 했는지 말한다).
const String sentenceSaveFailedMessage = '문장을 저장하지 못했어요. 다시 시도해 주세요.';

/// 무엇이 안 됐는지 딱 집어 말할 수 없을 때.
const String actionFailedMessage = '처리하지 못했어요. 다시 시도해 주세요.';

/// 목록·내용을 불러오지 못했을 때. 뒤에 '다시 시도' 단추를 함께 둔다.
const String loadFailedMessage = '불러오지 못했어요.';

/// 지우지 못했을 때. 커뮤니티의 deleteFailedMessage와 같은 말이다.
const String deleteFailedShortMessage = '지우지 못했어요. 잠시 뒤 다시 해 주세요.';
