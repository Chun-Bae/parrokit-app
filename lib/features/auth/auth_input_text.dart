// 로그인·가입·비밀번호 찾기의 입력 안내(5차 415).
//
// 세 화면이 같은 말을 각자 적고 있었다. 그래서 같은 화면 안에서도
// 서버 응답을 옮긴 글은 '이메일 형식이 올바르지 않아요.'인데 입력칸
// 아래에는 '올바른 이메일 형식이 아닙니다.'가 떴다. '입력해 주세요'도
// 앱의 다른 곳('적어 주세요', nickname_rule)과 달랐다.

/// 이메일을 비워 두고 눌렀을 때.
const String emailNeededMessage = '이메일을 적어 주세요.';

/// 이메일 모양이 아닐 때. 서버 오류를 옮길 때도 같은 말을 쓴다.
const String emailInvalidMessage = '이메일 형식이 올바르지 않아요.';

/// 비밀번호를 비워 두고 눌렀을 때.
const String passwordNeededMessage = '비밀번호를 적어 주세요.';

/// 비밀번호가 너무 짧을 때.
const String passwordShortMessage = '비밀번호는 6자 이상이어야 해요.';

/// 가입에서 비밀번호를 한 번 더 받을 때.
const String passwordAgainNeededMessage = '비밀번호를 한 번 더 적어 주세요.';

/// 비밀번호 찾기 화면의 안내.
const String findPasswordGuide = '가입한 이메일을 적으면 비밀번호를 다시 정하는 링크를 보내 드려요.';
