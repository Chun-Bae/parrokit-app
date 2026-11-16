// 영상이 없을 때 무엇을 하면 되는지 말한다(5차 326).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/missing_video_text.dart';

void main() {
  test('서버에만 있는 클립은 받으라고 한다', () {
    expect(missingVideoHint('server'), videoNotOnDeviceHint);
    expect(missingVideoHint('server'), contains('받아'));
  });

  test('기기 클립은 파일이 사라졌다고 한다', () {
    expect(missingVideoHint('local'), videoMissingHint);
    expect(missingVideoHint('gdrive'), videoMissingHint);
    expect(missingVideoHint(''), videoMissingHint);
  });

  test('같은 말을 화면마다 따로 적지 않는다', () {
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('missing_video_text.dart'))
        .where((f) => f.readAsStringSync().contains("'영상 파일을 찾을 수 없어요."))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty);
  });
}
