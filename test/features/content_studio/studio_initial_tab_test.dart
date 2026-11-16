// 영상 만들기 길로 들어왔는데 지금 숨겨져 있을 때(5차 384).
//
// 전에는 말없이 음성 만들기 탭으로 밀어 넣었다. 알림이나 예전 링크로 들어온
// 사람은 왜 다른 화면인지 알 수 없었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/hub/presentation/content_studio_hub_screen.dart';

void main() {
  test('영상 만들기가 켜져 있으면 그대로 연다', () {
    final tab = studioInitialTab(2, videoEnabled: true);
    expect(tab.index, 2);
    expect(tab.moved, isFalse);
  });

  test('숨겨져 있으면 음성 만들기로 밀되, 옮겼다고 알린다', () {
    final tab = studioInitialTab(2, videoEnabled: false);
    expect(tab.index, 1);
    expect(tab.moved, isTrue);
  });

  test('있는 탭은 그대로', () {
    for (final requested in [0, 1]) {
      final tab = studioInitialTab(requested, videoEnabled: false);
      expect(tab.index, requested);
      expect(tab.moved, isFalse);
    }
  });

  test('범위를 벗어난 번호도 안전하게', () {
    expect(studioInitialTab(-3, videoEnabled: false).index, 0);
    expect(studioInitialTab(9, videoEnabled: true).index, 2);
  });

  test('챗봇과 들어오는 길이 같은 말을 쓴다', () {
    final code = File(
            'lib/features/content-studio/hub/presentation/content_studio_hub_screen.dart')
        .readAsStringSync();
    expect(videoStudioRestingMessage, '영상 만들기는 지금 쉬고 있어요.');
    // 같은 글을 두 번 적어 두지 않는다.
    expect("'영상 만들기는 지금 쉬고 있어요.'".allMatches(code).length, 1);
    expect('showToast(videoStudioRestingMessage)'.allMatches(code).length, 2);
  });
}
