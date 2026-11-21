/// 안 써도 되는 칸의 이름(5차 420, 436).
///
/// '(선택)'은 고르라는 말처럼 읽혀 '(비워도 돼요)'로 바꿨는데, 그 뒤로도
/// 화면마다 손으로 적고 있었다(문장 추가·문장 상세·단어 상세 네 자리).
String optionalFieldLabel(String name) => '$name (비워도 돼요)';

const String pronunciationOptionalLabel = '발음 (비워도 돼요)';
const String meaningOptionalLabel = '뜻 (비워도 돼요)';

/// 뜻이나 발음으로 원문을 만드는 단추(5차 540·541, 사용자 요청).
///
/// '만들기'만으로는 무엇이 만들어지는지 알 수 없었다(사용자 지적).
/// 뜻칸 옆과 발음칸 옆 모두 같은 말을 쓴다 - 하는 일이 같고 재료만 다르다.
const String makeSentenceLabel = '원문 생성';
