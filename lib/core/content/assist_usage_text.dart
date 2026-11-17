// 뜻 채우기 하루 한도 안내(5차 445).
//
// 문장 추가 화면과 단어 상세가 같은 말을 각자 적고 있었다. 단어 쪽은
// 함수로 빼 뒀는데 문장 쪽은 화면 안에 그대로 있어서, 한쪽만 다듬으면
// 갈라진다.
//
// 숫자만 있으면('0 / 3') 쓴 횟수인지 남은 횟수인지 알 수 없어 '오늘 N/M회
// 사용'으로 적는다.

/// 오늘 몇 번 썼는지. 서버가 알려 주지 않으면 null.
String? assistUsageLabel({required int? used, required int? limit}) {
  if (used == null || limit == null) return null;
  return '오늘 $used/$limit회 사용';
}

/// 아직 받아 오는 중.
const String assistUsageLoadingLabel = '횟수 확인 중…';

/// 못 받았을 때. 누르면 다시 확인한다는 것까지 적는다.
const String assistUsageUnknownLabel = '횟수를 확인하지 못했어요 · 탭해서 다시 확인';
