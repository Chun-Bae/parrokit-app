// 음성으로 만들 글의 길이 규칙(5차 434).
//
// 240이라는 수가 네 곳(여기, provider, 화면의 글자 수, 입력칸 maxLength)에
// 손으로 적혀 있었다. 한 곳만 바꾸면 화면과 검사가 어긋난다.

/// 한 번에 읽어 줄 수 있는 글자 수.
const int maxTtsTextLength = 240;

/// 길이를 넘겼을 때. 화면은 이 칸을 '읽을 글'이라 부른다('텍스트'가 아니다).
String ttsTextTooLongMessage(int max) => '읽을 글은 $max자까지 쓸 수 있어요.';

class TtsValidator {
  static void validateText(String text) {
    if (text.trim().isEmpty) {
      throw Exception('읽을 글을 적어 주세요.');
    }
    if (text.length > maxTtsTextLength) {
      throw Exception(ttsTextTooLongMessage(maxTtsTextLength));
    }
  }
}
