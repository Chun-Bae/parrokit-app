// 서버를 부를 때 기다릴 시간(5차 447).
//
// 같은 결함이 세 번 났다: 목소리 목록(395), 챗봇 사용량(429), 뜻 채우기
// 횟수(446). 모두 기다림에 끝이 없어서 돌아가는 표시가 영영 남았다.
// 그래서 서버를 부르는 자리는 모두 둘 중 하나를 쓴다.

/// 묻고 바로 답이 오는 일(조회·등록·토큰 받기).
const Duration shortCallTimeout = Duration(seconds: 15);

/// 서버가 무언가를 만들어 주는 일(챗봇 답, 음성·자막 만들기).
/// 짧게 끊으면 멀쩡히 되던 것도 실패로 보인다.
const Duration generateCallTimeout = Duration(seconds: 60);
