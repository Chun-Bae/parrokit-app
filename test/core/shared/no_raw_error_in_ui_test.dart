// 화면 글에 내부 오류 객체를 그대로 넣지 않게 지킨다(5차).
//
// 최근 본 클립 화면이 '오류가 발생했어요\n${snap.error}'처럼 내부 글을 그대로
// 보여 주고 있었다. 사용자는 고칠 수 없는 내용이고, 서버·파일 경로가 비칠 수도
// 있다. 안내는 사람 말로 적고 자세한 것은 AppLogger로 남긴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 글 안에 끼워 넣으면 안 되는 것. 로그는 AppLogger의 error 인자로 넘기므로
/// 글 안에 넣을 일이 없다. 여는 따옴표와 같은 줄만 보면 놓치므로(원래 코드는
/// Text( 다음 줄에 글이 있었다) 글 조각만 본다.
final _offenderPatterns = <RegExp>[
  RegExp(r'\$\{(snap|snapshot)\.error\}'),
  RegExp(r'\$\{e\.toString\(\)\}'),
  RegExp(r'\$\{error\.toString\(\)\}'),
];

void main() {
  test('화면 글에 내부 오류 객체를 그대로 넣지 않는다', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final pattern in _offenderPatterns) {
          if (pattern.hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '사람 말로 된 안내로 바꾸고 자세한 것은 AppLogger로 남기세요.');
  });
}
