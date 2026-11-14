// TTS 화면이 쓰는 말(5차).
//
// '스크립트'·'톤 (-20 ~ 20)'·'생성 미리보기'는 앱의 다른 화면에서 쓰지 않는
// 말이거나 무엇을 뜻하는지 알기 어려웠다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('화면 글에 내부 말이나 뜻 모를 눈금이 없다', () {
    final screen = _code(
      'lib/features/content-studio/tts/presentation/screens/tts_screen.dart',
    );
    expect(screen.contains("title: '스크립트'"), isFalse);
    expect(screen.contains('톤 (-20 ~ 20)'), isFalse);
    expect(screen, contains("title: '읽을 글'"));
    expect(screen, contains("label: '목소리 높낮이'"));
    expect(screen, contains("title: '미리 듣기'"));
  });

  test('빈 미리 듣기 안내가 앱 말투를 쓴다', () {
    final player = _code(
      'lib/features/content-studio/tts/presentation/widgets/tts_audio_player_widget.dart',
    );
    expect(player.contains('확인합니다'), isFalse);
    expect(player, contains('읽을 글을 적으면'));
  });
}
