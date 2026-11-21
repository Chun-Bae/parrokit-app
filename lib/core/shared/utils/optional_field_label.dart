/// 안 써도 되는 칸의 이름(5차 420, 436).
///
/// '(선택)'은 고르라는 말처럼 읽혀 '(비워도 돼요)'로 바꿨는데, 그 뒤로도
/// 화면마다 손으로 적고 있었다(문장 추가·문장 상세·단어 상세 네 자리).
String optionalFieldLabel(String name) => '$name (비워도 돼요)';

const String pronunciationOptionalLabel = '발음 (비워도 돼요)';
const String meaningOptionalLabel = '뜻 (비워도 돼요)';

/// 위에 적은 한글 소리를 발음칸으로 가져오는 단추(5차 539, 사용자 요청).
///
/// 한글 전사는 '곤니치와'처럼 소리를 적어 こんにちは를 받는 기능이다.
/// 그 소리가 곧 발음인데 발음칸에 똑같이 다시 쳐야 했다.
const String copyHangulLabel = '가져오기';
