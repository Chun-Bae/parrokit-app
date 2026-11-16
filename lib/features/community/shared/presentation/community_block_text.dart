// 차단과 관련해 화면에 적는 말(5차 408).
//
// 차단 목록 화면과 글·댓글 옵션의 '차단'이 따로 글을 적고 있어서,
// 실패 안내가 '차단에 실패했어요.'(예전 말투)로 남아 있었고 목록의 이름
// 자리 기본값도 '이름 없음'이라 다른 화면('알 수 없음')과 달랐다.

/// 메뉴 줄과 화면 제목에 쓰는 이름. 둘이 같아야 들어온 곳을 알 수 있다.
const String blockedUsersTitle = '차단한 사용자';

/// 차단하지 못했을 때. 지우기 실패 안내와 같은 결로 적는다.
const String blockFailedMessage = '차단하지 못했어요. 잠시 뒤 다시 해 주세요.';

/// 차단을 풀지 못했을 때.
const String unblockFailedMessage = '차단을 풀지 못했어요. 잠시 뒤 다시 해 주세요.';

/// 차단했을 때.
const String blockedMessage = '차단했어요.';

/// 차단을 풀었을 때. 단추도 '차단 풀기'라고 부른다('해제'는 쓰지 않는다).
const String unblockedMessage = '차단을 풀었어요.';

/// 차단을 푸는 단추 이름.
const String unblockLabel = '차단 풀기';

/// 자기 자신을 차단하려 할 때. 전에는 '본인 닉네임이에요.'라고만 해서
/// 무엇이 안 되는 것인지 말하지 않았다.
const String blockSelfMessage = '내 닉네임이에요. 나는 차단할 수 없어요.';
