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
const String sentenceShareNeedsNickname = '닉네임을 먼저 설정해주세요.';

/// 로그인하지 않으면 공유할 수 없다. 공유한 문장은 서버에 올라가기 때문이다
/// (5차 346). 전에는 게스트에게도 '공유' 단추를 보여 주고, 누르면 닉네임이
/// 없다고만 말해 까닭이 엉뚱했다.
const String sentenceShareNeedsLogin = '로그인하면 내 문장을 둘러보기에 공유할 수 있어요.';
