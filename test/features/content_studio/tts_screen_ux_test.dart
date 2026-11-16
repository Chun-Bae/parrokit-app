// 음성 만들기 화면을 친절하게 바꾼 것을 지킨다(5차 411, 사용자 요청).
//
// 요청: "TTS 목록도 많고 옵션 설정이 불친절. mp3로 저장·클립으로 만들기가
// 직관적이지 않다. 카드형 디자인부터 버리자."
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/tts/presentation/tts_file_name.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('내려받는 파일 이름에 날짜가 들어간다', () {
    final name = ttsFileName(DateTime(2026, 11, 17, 9, 5, 3));
    expect(name, 'Parrokit_음성_20261117_090503');
    // 전에는 '${DateTime.now()...}'가 글자 그대로 파일 이름이 됐다.
    expect(name, isNot(contains(r'$')));
    expect(name, isNot(contains('DateTime')));
  });

  test('묶음은 카드가 아니라 제목 한 줄이다', () {
    final panel = _code('lib/features/content-studio/tts/presentation/'
        'widgets/tts_panel.dart');
    // 테두리와 둥근 상자를 버렸다.
    expect(panel, isNot(contains('Border.all')));
    expect(panel, isNot(contains('BorderRadius')));
  });

  test('자주 안 쓰는 설정은 접어 둔다', () {
    final screen = _code('lib/features/content-studio/tts/presentation/'
        'screens/tts_screen.dart');
    expect(screen, contains("ValueKey('tts-more-options')"));
    expect(screen, contains('자세한 설정'));
    // 영어 이름을 그대로 쓰던 슬라이더 제목.
    expect(screen, isNot(contains('(Stability)')));
    expect(screen, isNot(contains('(Clarity)')));
    expect(screen, isNot(contains('(Speaker Boost)')));
  });

  test('만든 뒤 할 일은 무엇을 하는지로 적는다', () {
    final screen = _code('lib/features/content-studio/tts/presentation/'
        'screens/tts_screen.dart');
    expect(screen, contains('자막 넣어 클립 만들기'));
    expect(screen, contains('mp3 파일로 내려받기'));
    expect(screen, contains('지우고 다시 만들기'));
    // 예전 이름들.
    expect(screen, isNot(contains("Text('자막 생성')")));
    expect(screen, isNot(contains("Text('저장')")));
    expect(screen, isNot(contains('생성 결과 관리')));
  });
}
