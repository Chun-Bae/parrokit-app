// '소리만 듣기'(예전 '백그라운드') 말과 안내(5차).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/player/presentation/audio_only_label.dart';

void main() {
  test('하는 일로 부른다', () {
    expect(audioOnlyLabel, '소리만 듣기');
    expect(audioOnlyLabel.contains('백그라운드'), isFalse);
  });

  test('안내가 왜 다른 조작이 꺼지는지까지 말한다', () {
    expect(audioOnlyNotice, contains('소리만'));
    expect(audioOnlyNotice, contains('화면을 꺼도'));
    // 흐려진 버튼이 고장이 아니라는 것을 알려 준다.
    expect(audioOnlyNotice, contains('끄면'));
    expect(audioOnlyNotice.contains('백그라운드'), isFalse);
  });
}
