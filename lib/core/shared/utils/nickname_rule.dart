/// 닉네임 규칙. 온보딩과 프로필 수정이 같은 값을 쓴다.
///
/// 전에는 프로필 수정에만 15자 제한이 있고 온보딩에는 없었다. 그래서 처음에
/// 16자가 넘는 닉네임을 만들면 나중에 프로필 수정 화면에서는 그 길이를 다시
/// 칠 수 없어 고치지도 못했다(5차).
const int nicknameMaxLength = 15;

/// 닉네임 검사 안내. 온보딩·회원가입·프로필 수정이 같은 말을 쓴다(5차 317).
///
/// 전에는 세 화면에 같은 글이 따로 적혀 있어서, 한 곳의 말을 다듬으면
/// 나머지는 예전 말로 남았다. '입력해주세요'도 앱의 다른 곳('~해 주세요')과
/// 달랐다.
const String nicknameNeededMessage = '닉네임을 적어 주세요.';
const String nicknameAvailableMessage = '쓸 수 있는 이름이에요.';
const String nicknameTakenMessage = '이미 누가 쓰고 있어요.';

