// 같은 일을 '변경'과 '바꾸기'로 나눠 부르던 것(5차 490).
//
// 폴더 이름을 고치는 일을 새 보관함 화면은 '이름 바꾸기'·'바꾸기'라 하고
// 예전 화면은 '폴더 이름 변경'·'변경'이라 했다. 프로필 편집은 한 화면
// 안에서 갈렸다 - 사진 아래는 '사진을 눌러 변경'인데 바로 밑 안내는
// '바꿀 수 있어요'·'바꾼 날은'·'바꾸면'이었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 주석을 뺀, 화면에 보이는 글만 남긴 소스.
String _visible(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .where((line) => !line.trimLeft().startsWith('///'))
    .join('\n');

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

// 한 줄 안의 따옴표 글만 본다. 줄바꿈까지 넘기면 파일 전체가 한 덩이로 잡힌다.
final _quoted = RegExp(r"'[^'\n]*변경[^'\n]*'");

void main() {
  test("화면에 보이는 글에 '변경'을 쓰지 않는다", () {
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      for (final match in _quoted.allMatches(_visible(file))) {
        offenders.add('${file.path}: ${match.group(0)}');
      }
    }
    expect(offenders, isEmpty, reason: "같은 일은 '바꾸기'로 적는다");
  });

  test('이름 고치기는 어디서나 바꾸기라 부른다', () {
    final folder = _visible(File('lib/features/collection/library/'
        'presentation/sections/library_folder_section.dart'));
    expect(folder, contains("'폴더 이름 바꾸기'"));
    expect(folder, contains("'그룹 이름 바꾸기'"));
    expect(folder, contains("submitLabel: '바꾸기'"));

    // 새 보관함 화면이 쓰던 말과 같다.
    final picker = _visible(File('lib/features/collection/library/'
        'presentation/folder_picker_sheet.dart'));
    expect(picker, contains("'폴더 이름 바꾸기'"));
  });

  test('프로필 편집은 한 화면 안에서 갈리지 않는다', () {
    final code = _visible(File(
        'lib/features/settings/more/presentation/profile_edit_screen.dart'));
    expect(code, contains("'사진을 눌러 바꾸기'"));
    expect(code, contains('바꿀 수 있어요'));
  });
}
