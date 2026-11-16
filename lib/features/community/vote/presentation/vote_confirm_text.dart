// 투표 확인 창의 글. 다른 확인 창(글·댓글·알림 지우기)과 같은 꼴로 둔다.
//
// 예전에는 '투표 확인' / '…항목에 투표하시겠습니까? 한 번 투표하면 수정할
// 수 없습니다.'였다. 제목은 명사 나열이고 본문만 '~습니다'라 앱의 다른
// 확인 창과 어긋났다(5차).

const String voteConfirmTitle = '투표하기';

String voteConfirmMessage(String option) =>
    "'$option'에 투표할까요?\n한 번 투표하면 바꿀 수 없어요.";

/// 투표가 막혔는데 까닭을 받지 못했을 때 쓰는 말(5차 381).
const String voteFailedText = '투표하지 못했어요. 잠시 뒤 다시 해 주세요.';
