// 만들기 도우미(챗봇)가 제 할 일을 밝히는 말(5차 502).
//
// 세 자리가 같은 것을 저마다 적어 서로 어긋났다. 음성 만들기 화면에서 챗봇을
// 열면 모드는 'general'인데,
//   - 머리줄 부제는 모드를 보고 '무엇이든 물어보세요'
//   - 첫 인사는 kVideoStudioEnabled를 보고 '음성 만들기를 도와줄 챗봇이에요'
//   - 입력 칸 힌트도 같은 깃발을 보고 '음성으로 만들 내용을 적어 보세요...'
// 라고 했다. 한 화면이 '무엇이든 물어보라'면서 적는 칸에는 음성 이야기만
// 적으라고 한 셈이다. 모드를 '음성 전문가'로 바꿔도 힌트는 그대로여서,
// 두 모드가 같은 힌트를 썼다.
//
// 이제 셋 다 **지금 모드**만 보고, 그 말을 여기 한 곳에 둔다.

/// 챗봇 모드. 서버(`chatbotFlow`)가 쓰는 값과 같아야 한다.
const String chatBotGeneralMode = 'general';
const String chatBotTtsMode = 'tts';
const String chatBotVideoMode = 'video';

/// 머리줄 이름 아래 한 줄.
String chatBotSubtitle(String mode) => switch (mode) {
      chatBotTtsMode => '음성 만들기를 도와줄게요',
      chatBotVideoMode => '영상 만들기를 도와줄게요',
      _ => '무엇이든 물어보세요',
    };

/// 대화를 열거나 새로 시작할 때의 첫 인사.
String chatBotGreeting(String mode) => switch (mode) {
      chatBotTtsMode => '안녕하세요! 음성 만들기를 도와줄게요.\n어떤 음성을 만들고 싶으신가요?',
      chatBotVideoMode => '안녕하세요! 영상 만들기를 도와줄게요.\n어떤 영상을 만들고 싶으신가요?',
      _ => '안녕하세요! 만들기를 도와줄 챗봇이에요.\n무엇이든 물어보세요.',
    };

/// 적는 칸에 흐리게 적어 두는 말.
String chatBotInputHint(String mode) => switch (mode) {
      chatBotTtsMode => '음성으로 만들 내용을 적어 보세요...',
      chatBotVideoMode => '영상으로 만들 내용을 적어 보세요...',
      _ => '무엇이든 물어보세요...',
    };
