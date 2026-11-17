// 자동 자막 기능을 한 이름으로 부른다(5차 427).
//
// 같은 기능을 네 가지로 불렀다: 단추는 '자동 자막 생성', 확인 창 제목은
// '자막 자동 생성', 진행 글은 '자동 자막 생성 중'과 'AI 자막 생성 중...'.
// 앱은 '만들기'를 쓴다(음성 만들기·영상 만들기·클립 만들기).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/data/constants/edit_strings.dart';

const _home =
    'lib/features/content-studio/captioning/data/constants/edit_strings.dart';

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

List<String> _uiLines(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .toList();

void main() {
  test("'생성' 대신 '만들기'로 부른다", () {
    expect(EditStrings.sttButtonLabel, '자동 자막 만들기');
    expect(EditStrings.sttConfirmTitle, EditStrings.sttButtonLabel);
    expect(EditStrings.sttRunningLabel, '자동 자막 만드는 중');
  });

  test('예전 이름 네 가지가 화면에 남아 있지 않다', () {
    const gone = [
      '자동 자막 생성',
      '자막 자동 생성',
      '자동 자막 생성 중',
      'AI 자막 생성 중',
    ];
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      if (file.path.endsWith(_home)) continue;
      for (final line in _uiLines(file)) {
        if (!line.contains("'")) continue;
        for (final name in gone) {
          if (line.contains(name)) offenders.add('${file.path}: $name');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('실패 안내도 한 곳에서 꺼낸다', () {
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      if (file.path.endsWith(_home)) continue;
      for (final line in _uiLines(file)) {
        if (line.contains("'${EditStrings.sttFailedMessage}'")) {
          offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
