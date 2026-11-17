// 같은 말을 여러 화면이 손으로 적지 않는다(5차 436).
//
// 만들기 입구가 셋인데(콘텐츠 제작 첫 화면, 보관함 '무엇을 추가할까요?',
// 홈 무대 전환 단추) 설명을 각자 적다 보니, 같은 클립 만들기를 한쪽은
// '영상에 자막을 달아 클립으로 저장해요', 다른 쪽은 '영상과 자막을 함께
// 보관해요'라고 했다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/optional_field_label.dart';
import 'package:parrokit/features/community/shared/presentation/write_blocked_reason.dart';
import 'package:parrokit/features/content-studio/hub/presentation/studio_tab_names.dart';

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

List<String> _handWritten(String text, String home) => _dartFiles()
    .where((f) => !f.path.endsWith(home))
    .where((f) => f
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .any((l) => l.contains("'$text'")))
    .map((f) => f.path)
    .toList();

void main() {
  test('만들기 입구 설명을 한 곳에서 꺼내 쓴다', () {
    const home = 'studio_tab_names.dart';
    for (final text in [
      studioClipTabDescription,
      studioVoiceTabDescription,
      studioVideoTabDescription,
    ]) {
      expect(_handWritten(text, home), isEmpty, reason: text);
    }
    // 예전에 갈려 있던 말이 돌아오지 않는다.
    expect(_handWritten('영상과 자막을 함께 보관해요', home), isEmpty);
    expect(_handWritten('영상에 자막을 달아 클립으로 저장해요', home), isEmpty);
  });

  test('안 써도 되는 칸 이름을 한 곳에서 꺼내 쓴다', () {
    const home = 'optional_field_label.dart';
    expect(optionalFieldLabel('발음'), pronunciationOptionalLabel);
    expect(optionalFieldLabel('뜻'), meaningOptionalLabel);
    for (final text in [pronunciationOptionalLabel, meaningOptionalLabel]) {
      expect(_handWritten(text, home), isEmpty, reason: text);
    }
  });

  test('글쓰기 제목 힌트를 두 화면이 함께 쓴다', () {
    expect(writeTitleHint, '제목을 적어 주세요');
    expect(_handWritten(writeTitleHint, 'write_blocked_reason.dart'), isEmpty);
  });
}
