// 콘텐츠 제작 허브 탭 제목(5차). 들어온 입구와 같은 말을 쓴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('클립 만들기 화면은 어느 길로 열어도 제목이 같다', () {
    // 같은 화면을 /clips/create로 바로 열면 '새 클립'인데, 허브 탭으로
    // 열면 '편집'이라 새로 만드는 화면인데 고치러 온 것처럼 보였다.
    final hub = File(
            'lib/features/content-studio/hub/presentation/content_studio_hub_screen.dart')
        .readAsStringSync();
    expect(hub, contains("0 => '새 클립'"));
    expect(hub.contains("0 => '편집'"), isFalse);

    final create = File(
            'lib/features/content-studio/captioning/presentation/screens/captioning_screen.dart')
        .readAsStringSync();
    // 그 화면은 고치러 들어오면 '클립 편집', 새로 만들면 '새 클립'이다.
    expect(create, contains("vm.clipId != null ? '클립 편집' : '새 클립'"));
  });

  test('TTS 탭 제목은 들어온 입구와 같다', () {
    final hub = File(
            'lib/features/content-studio/hub/presentation/content_studio_hub_screen.dart')
        .readAsStringSync();
    final entry = File(
            'lib/features/collection/shell/presentation/collection_shell_screen.dart')
        .readAsStringSync();
    expect(hub, contains("1 => 'TTS 음성 만들기'"));
    expect(entry, contains("title: 'TTS 음성 만들기'"));
  });
}
