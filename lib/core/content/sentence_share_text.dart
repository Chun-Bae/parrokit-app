// 둘러보기 공유를 묻는 말(5차 340).
//
// 같은 말이 문장 상세, 내 문장 목록의 밀기 동작, 커뮤니티 문장 탭의 공유
// 시트 세 곳에 따로 적혀 있었다. 한 곳에 둔다.

import 'package:parrokit/core/content/shared_sentence_repository.dart';

String sentenceShareTitle({required bool published}) =>
    published ? '공유를 취소할까요?' : '둘러보기에 공유할까요?';

String sentenceShareBody({
  required bool published,
  required String authorName,
}) =>
    published
        ? '둘러보기에서 사라지고 좋아요 수와 가져간 수도 함께 사라져요.\n'
            '이미 가져간 사람의 문장은 그대로 남아요. 내 문장함에는 계속 있어요.'
        : '공개되는 것: 문장, 뜻, 발음, 작성자 "$authorName"\n'
            '공개되지 않는 것: 들은 횟수, 연습 기록, 친밀도, 메모\n\n'
            '언제든 공유를 취소할 수 있어요. 하루에 '
            '${SharedSentenceRepository.dailyShareLimit}개까지 공유할 수 있어요.';

String sentenceShareConfirmLabel({required bool published}) =>
    published ? '공유 취소' : '공유';

String sentenceShareCancelLabel({required bool published}) =>
    published ? '그대로 두기' : '취소';

/// 닉네임이 없으면 공유할 수 없다. 공개 목록에 이름이 함께 올라가기 때문이다.
const String sentenceShareNeedsNickname = '닉네임을 먼저 설정해 주세요.';

/// 로그인하지 않으면 공유할 수 없다. 공유한 문장은 서버에 올라가기 때문이다
/// (5차 346). 전에는 게스트에게도 '공유' 단추를 보여 주고, 누르면 닉네임이
/// 없다고만 말해 까닭이 엉뚱했다.
const String sentenceShareNeedsLogin = '로그인하면 내 문장을 둘러보기에 공유할 수 있어요.';

// ── 공유·가져오기 결과 안내(5차 421) ─────────────────────────────────
//
// 보관함 문장 목록, 문장 상세 시트, 공유 시트, 홈 둘러보기 줄이 같은 말을
// 각자 적고 있었다. 그중 하나는 '추가했어요. 홈 앵무새가 말해줘요.'로
// 달랐고, 하루 한도 안내는 예외의 toString()을 글 앞에 붙여 만들었다
// ('$e 내일 다시 공유해 주세요.'). 예외 글은 개발자용이라 화면에 쓰지 않는다.

/// 둘러보기에 공유했을 때.
const String sentenceSharedMessage = '둘러보기에 공유했어요.';

/// 공유를 거뒀을 때.
const String sentenceShareCanceledMessage = '공유를 취소했어요.';

/// 하루에 공유할 수 있는 수를 다 썼을 때.
String sentenceShareLimitMessage(int limit) =>
    '하루에 $limit개까지 공유할 수 있어요. 내일 다시 공유해 주세요.';

/// 남의 문장을 내 문장으로 가져왔을 때.
const String sentenceSavedToMineMessage = '내 문장에 저장했어요. 홈 앵무새가 말해줘요.';

/// 이미 같은 문장을 갖고 있을 때.
const String sentenceAlreadySavedMessage = '이미 있는 문장이에요.';

/// 가져왔던 문장을 다시 뺐을 때.
const String sentenceRemovedFromMineMessage = '내 문장에서 뺐어요.';

/// 내가 올린 문장이라 여기서는 뺄 수 없을 때.
const String sentenceIsMineMessage = '내가 올린 문장이에요. 지우려면 내 문장에서 지워 주세요.';

// ── 공유 문장 카드의 단추와 좋아요(5차 426) ─────────────────────────
//
// 보관함 둘러보기 줄과 홈 둘러보기 줄이 같은 카드를 각자 그리면서 글도
// 각자 적었다. 그래서 **보관함 쪽 북마크 단추는 이미 저장한 뒤에도 설명이
// '내 문장에 저장'이었다.** 누르면 빼는데 저장이라고 적혀 있었다.

/// 북마크 단추 설명. 저장했으면 누를 때 빠지므로 그렇게 적는다.
String saveToMineTooltip({required bool saved}) =>
    saved ? '내 문장에서 빼기' : '내 문장에 저장';

/// 로그인하지 않고 좋아요를 눌렀을 때.
const String likeNeedsLoginMessage = '로그인하면 좋아요를 누를 수 있어요.';

/// 좋아요를 서버에 남기지 못했을 때.
const String likeFailedMessage = '좋아요를 저장하지 못했어요. 다시 시도해 주세요.';

/// 내 문장을 둘러보기에 올리는 자리의 이름.
const String shareMySentenceLabel = '내 문장 공유하기';
