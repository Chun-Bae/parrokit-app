// 읽을 글 길이 규칙(5차 442).
//
// 434에서 240이라는 수를 한 곳으로 모았지만, **한도를 넘겼을 때의 안내는
// 240자를 채워야 떠서 기기에서 못 봤다**. 입력칸이 maxLength로 막으니
// 화면에서는 거의 안 뜨지만, 붙여넣기·자동 채우기처럼 칸을 거치지 않는
// 길이 있으면 이 검사가 마지막 문이다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/tts/domain/validators/tts_validator.dart';

void main() {
  test('비어 있으면 적으라고 한다', () {
    expect(
      () => TtsValidator.validateText('   '),
      throwsA(predicate((e) => e.toString().contains('읽을 글을 적어 주세요.'))),
    );
  });

  test('딱 한도까지는 넘긴다', () {
    expect(
      () => TtsValidator.validateText('가' * maxTtsTextLength),
      returnsNormally,
    );
  });

  test('한도를 넘기면 몇 자까지인지 말한다', () {
    expect(
      () => TtsValidator.validateText('가' * (maxTtsTextLength + 1)),
      throwsA(predicate(
          (e) => e.toString().contains(ttsTextTooLongMessage(maxTtsTextLength)))),
    );
    expect(ttsTextTooLongMessage(maxTtsTextLength), contains('240자까지'));
  });
}
