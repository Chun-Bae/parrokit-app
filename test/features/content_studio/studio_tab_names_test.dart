// 스튜디오 탭 이름(5차).
//
// 아래 칸은 '자막'인데 열리는 화면 제목은 '새 클립'이었다. 들어가는 칸,
// 허브 안내, 화면 제목이 한 곳에서 같은 말을 가져다 쓰는지 지킨다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/hub/presentation/studio_tab_names.dart';

void main() {
  test('탭 이름은 화면이 하는 일을 말한다', () {
    expect(studioClipTabName, '새 클립');
    expect(studioVoiceTabName, '음성 만들기');
    expect(studioVideoTabName, '영상 만들기');
  });

  test('이름이 서로 겹치지 않는다', () {
    final names = {studioClipTabName, studioVoiceTabName, studioVideoTabName};
    expect(names.length, 3);
  });

  test('화면 말에 내부 용어가 없다', () {
    for (final name in [
      studioClipTabName,
      studioVoiceTabName,
      studioVideoTabName,
    ]) {
      for (final word in ['TTS', 'Video', '생성', '스튜디오']) {
        expect(name.contains(word), isFalse, reason: '"$word"는 화면 말이 아니다');
      }
    }
  });

  testWidgets('허브 안내와 아래 칸이 같은 이름을 쓴다', (tester) async {
    // 같은 상수를 쓰므로 한 곳만 고쳐도 둘이 어긋나지 않는다.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          Text(studioClipTabName),
          Text(studioVoiceTabName),
        ]),
      ),
    ));

    expect(find.text('새 클립'), findsOneWidget);
    expect(find.text('자막'), findsNothing, reason: '화면 제목과 달랐던 옛 이름');
  });
}
