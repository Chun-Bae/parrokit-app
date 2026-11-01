import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/speech/speech_match.dart';

void main() {
  test('대소문자와 문장부호는 무시한다', () {
    expect(speechMatchScore('Hello there!', 'hello there'), 1);
  });

  test('일부만 말하면 비율만큼 점수를 준다', () {
    expect(speechMatchScore('abcd', 'ab'), 0.5);
  });

  test('다른 문장은 낮고 빈 입력은 0이다', () {
    expect(speechMatchScore('Hello there', 'xyz'), lessThan(0.3));
    expect(speechMatchScore('Hello', ''), 0);
  });

  test('공백 없는 일본어, 중국어도 글자 단위로 비교한다', () {
    expect(speechMatchScore('こんにちは', 'こんにちは'), 1);
    expect(speechMatchScore('你好吗', '你好'), closeTo(2 / 3, 0.001));
  });
}
