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
    // 'TTS'는 영어 약어라 다른 줄('문장 추가·클립 추가')과 결이 달랐다(5차).
    expect(hub, contains("1 => '음성 만들기'"));
    expect(entry, contains("title: '음성 만들기'"));
  });

  test("화면에 보이는 글에 'TTS' 약어를 쓰지 않는다", () {
    // 모델 이름(Gemini 3.8 Flash TTS)과 로그 태그는 그대로 둔다.
    final offenders = <String>[];
    for (final entity
        in Directory('lib/features/content-studio').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in entity.readAsLinesSync()) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        if (line.contains('AppLogger') ||
            line.contains('[TTS]') ||
            line.contains('Gemini 3.8') ||
            line.contains('Parrokit_TTS')) {
          continue;
        }
        final match = RegExp(r"'[^']*TTS[^']*'").firstMatch(line)?.group(0);
        if (match != null) offenders.add('${entity.path}: $match');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
