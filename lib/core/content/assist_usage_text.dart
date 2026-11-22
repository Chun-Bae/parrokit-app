// 뜻 채우기 하루 한도 안내(5차 445).
//
// 문장 추가 화면과 단어 상세가 같은 말을 각자 적고 있었다. 단어 쪽은
// 함수로 빼 뒀는데 문장 쪽은 화면 안에 그대로 있어서, 한쪽만 다듬으면
// 갈라진다.
//
// 숫자만 있으면('0 / 3') 쓴 횟수인지 남은 횟수인지 알 수 없어 '오늘 N/M회
// 사용'으로 적는다.

import 'package:parrokit/core/shared/utils/korean_josa.dart';

/// 오늘 몇 번 썼는지. 서버가 알려 주지 않으면 null.
String? assistUsageLabel({required int? used, required int? limit}) {
  if (used == null || limit == null) return null;
  return '오늘 $used/$limit회 사용';
}

/// 앱바처럼 좁은 자리에 쓰는 짧은 꼴(5차 542).
///
/// '오늘 2/3회 사용'은 가운데 제목과 부딪힌다. 4.7인치 기기에서는 제목이
/// 잘린다. '사용'을 떼어도 앞의 '오늘'이 쓴 횟수라는 것을 말해 준다.
String? assistUsageShortLabel({
  required int? used,
  required int? limit,
  int credits = 0,
}) {
  if (used == null || limit == null) return null;
  // 사 둔 몫이 있으면 그것까지 적는다. 다음에 누르면 그 몫이 깎이므로
  // 하루치만 보여 주면 거짓말이 된다(5차 546).
  final head = '오늘 $used/$limit회';
  return credits > 0 ? '$head +$credits' : head;
}

/// 오늘 하루치를 몇 번 썼는지(5차 546).
///
/// 서버가 주는 remainingToday에는 패롯으로 사 둔 몫이 더해져 있다
/// (max(한도-쓴수, 0) + assistCredits). 그래서 한도에서 그냥 빼면 하루치를
/// 다 쓴 사람도 '오늘 2/3회'로 보였다. 기기에서 더보기 카드는 '3 / 3번 +1',
/// 문장 추가 앱바는 '오늘 2/3회 사용'으로 같은 수를 다르게 말했다.
///
/// 더 나쁜 것은 그 다음이다. 아직 한 번 남은 줄 알고 누르면 돈 주고 산
/// 몫이 깎였다.
int? assistUsedToday({
  required int? limit,
  required int? remaining,
  int credits = 0,
}) {
  if (limit == null || remaining == null) return null;
  final today = remaining - credits;
  return (limit - today).clamp(0, limit);
}

/// 아직 받아 오는 중.
const String assistUsageLoadingLabel = '횟수 확인 중…';

/// 횟수를 묻는 동안 채우기 단추 아래에 적을 말(5차 519).
///
/// 단추는 묻는 동안 막아 둔다(5차 515). 그런데 그 아래 줄은 그대로
/// '한 번만 채우면 돼요', '겹치지 않는 예문을 받아요'라고 적혀 있어서,
/// 누를 수 있는 단추가 안 눌리는 것처럼 보였다. 서버가 쉬다 깨는 첫
/// 조회는 30초 가까이 걸려서 그 동안 고장으로 읽힌다. 기다리는 중이라고
/// 적어 준다.
String assistFillHint({required bool loading, required String whenReady}) =>
    loading ? assistUsageLoadingLabel : whenReady;

/// 못 받았을 때. 누르면 다시 확인한다는 것까지 적는다.
const String assistUsageUnknownLabel = '횟수를 확인하지 못했어요 · 탭해서 다시 확인';

/// 앱바처럼 좁은 자리에 쓰는 짧은 말(5차 542).
const String assistUsageUnknownShortLabel = '횟수 ? · 다시 확인';

/// 빈 칸을 채우는 단추의 이름(5차 545, 사용자 요청).
///
/// 단추가 셋이던 때는 '뜻발음 생성'과 '원문 생성' 둘로 갈려 있었다. 하나로
/// 합치면서 셋을 다 적는다. '자동 채우기'는 예문까지 아우르는 상위 말이라
/// (더보기 카드 제목) 이 단추 이름으로 쓰면 예문과 구분되지 않는다.
const String fillBasicsLabel = '뜻·발음·원문 생성';

/// 단어 쪽 같은 단추의 이름(5차 555, 사용자 지적).
///
/// 단어에는 원문이 없다. 낱말이 곧 재료라 만드는 것은 뜻과 발음뿐이다.
/// '채우기'와 '생성'으로 갈려 있던 것을 '생성'으로 맞춘다.
const String wordFillBasicsLabel = '뜻·발음 생성';

/// 예문 단추의 이름. 더보기 카드도 '예문 생성'이라고 적는다.
const String wordFillExamplesLabel = '예문 생성';

/// 문장 추가에서 아직 아무것도 안 적어 채울 재료가 없을 때(5차 545).
///
/// 전에는 '문장을 적으면 채울 수 있어요'였다. 이제 뜻이나 발음만 적어도
/// 나머지를 채우므로 원문을 꼭 적어야 하는 것처럼 읽히면 안 된다.
const String fillNeedsAnyFieldHint = '원문, 뜻, 발음 가운데 하나만 적어도 돼요';

/// 셋 다 손으로 적어 두어 채울 칸이 없을 때(5차 545).
const String fillNothingLeftMessage = '빈 칸이 없어요.';

/// 손으로 적은 칸이 둘 이상일 때(5차 553, 사용자 결정).
///
/// 둘이 어긋나면 나머지 한 칸을 어느 쪽에 맞출지 알 수 없다. 모델은 아무
/// 말 없이 한쪽을 골라 버리므로, 아예 만들지 않는다.
const String fillRivalSourcesMessage = '한 칸만 적어 주세요. 두 칸이 서로 다르면 어느 쪽에 맞출지 알 수 없어요.';

/// 뜻과 발음이 이미 다 차 있어 채우기가 할 일이 없을 때(5차 525·526).
///
/// 단어 고치기 시트와 문장 추가 화면이 같은 말을 쓴다. 두 곳 모두 단추가
/// 켜진 채라 눌러도 아무 일이 없었고, 문장 쪽은 서버까지 불러 하루 횟수를
/// 한 번 버렸다.
/// 단어 쪽에서 쓴다. 한때 '하나라도 적혀 있으면'으로 좁혔다가 되돌렸다
/// (5차 557, 사용자 결정) - 단어는 재료가 낱말 하나뿐이라 어긋날 자리가
/// 없고, 사전에서 뜻을 보고 적은 뒤 발음만 받는 길이 흔하다.
const String assistBasicsDoneMessage = '뜻과 발음을 이미 적어 두었어요. 지우고 누르면 채워 드려요.';

/// 오늘 횟수를 다 썼을 때(5차 473 → 475에 문장 쪽과 합쳤다).
///
/// 문장 화면은 '오늘 횟수를 모두 썼어요', 단어 쪽은 '오늘 자동 채우기를
/// 모두 썼어요'로 갈려 있었다. 같은 일을 가리키니 한 말로 쓴다.
const String assistQuotaExhaustedMessage = '오늘 자동 채우기를 모두 썼어요. 내일 다시 쓸 수 있어요.';

/// 아직 적지 않아 채울 수 없을 때(5차 475).
///
/// 단추가 흐린데 까닭이 없으면 쓸 수 없는 기능인 줄 안다. 문장 화면과
/// 단어 화면이 같은 꼴로 말한다.
String assistNeedsTextHint(String what) =>
    '${eulReul(what)} 적으면 채울 수 있어요';

/// 오늘 횟수를 다 썼나(5차 478).
///
/// 단어 쪽에만 있던 것을 문장 화면도 쓰게 옮겼다. 문장 화면은 서버가
/// 거절한 뒤에야 다 쓴 줄 알아서, 열자마자 3/3인데도 '문장을 적으면
/// 채울 수 있어요'라고 적었다.
/// [credits]는 패롯으로 사 둔 몫이다. 하루치를 다 썼어도 그것이 남아
/// 있으면 아직 쓸 수 있다(5차 546).
bool assistExhausted({int? used, int? limit, int credits = 0}) =>
    credits <= 0 &&
    used != null &&
    limit != null &&
    limit > 0 &&
    used >= limit;
