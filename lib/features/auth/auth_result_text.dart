// 로그인·가입·비밀번호 찾기의 결과 안내(5차 416).
//
// 로그인 화면에만 '~습니다' 열네 곳이 남아 있었다. 게다가 소셜 로그인
// 네 가지가 성공·실패 글을 각자 적어, 같은 문장이 여덟 번 되풀이됐다.
// 앱의 다른 곳은 모두 '~어요'로 말한다.

/// 로그인했을 때. [how]는 '구글'·'카카오' 같은 방법 이름(이메일이면 비운다).
String signedInMessage([String how = '']) =>
    how.isEmpty ? '로그인했어요.' : '$how로 로그인했어요.';

/// 로그인을 마치지 못했을 때.
String signInFailedMessage([String how = '']) => how.isEmpty
    ? '로그인하지 못했어요. 잠시 뒤 다시 해 주세요.'
    : '$how 로그인을 마치지 못했어요. 잠시 뒤 다시 해 주세요.';

/// 가입을 마치지 못했을 때.
const String signUpFailedMessage = '가입하지 못했어요. 잠시 뒤 다시 해 주세요.';

/// 비밀번호 찾기 메일을 보냈을 때.
const String resetMailSentMessage = '비밀번호를 다시 정하는 메일을 보냈어요.';

/// 그 메일을 보내지 못했을 때.
const String resetMailFailedMessage = '메일을 보내지 못했어요. 잠시 뒤 다시 해 주세요.';

/// 그 이메일로 가입한 사람이 없을 때. 로그인과 비밀번호 찾기가 같은 말을
/// 쓴다(5차 437).
const String emailNotFoundMessage = '등록되지 않은 이메일이에요.';
