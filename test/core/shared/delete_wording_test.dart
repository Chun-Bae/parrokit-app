// 지우는 동작은 어디서나 '지우기'라 부른다(5차).
//
// 커뮤니티는 185에서 '지우기'로 바꿨는데 보관함·문장·단어·자막·투표·질문은
// 아직 '삭제'였다. 확인 창도 '삭제할까요?'와 '지울까요?'가 섞여 있었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test("화면 글에 '삭제' 버튼·확인 문구를 쓰지 않는다", () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        // 로그·예외 글은 사용자에게 보이지 않는다.
        if (line.contains('AppLogger') || line.contains('throw ')) continue;
        if (RegExp(r"'삭제'|삭제할까요|삭제하시겠|삭제합니다").hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: "'지우기'·'지울까요?'로 적으세요.");
  });

  test('조사를 받침에 맞게 붙인다', () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        // '폴더을'처럼 받침 없는 말에 '을'을 붙인 곳.
        if (RegExp(r"(폴더|클립|문장|단어|투표|그룹|영상)을[^가-힣]")
            .hasMatch(lines[i])) {
          final m = RegExp(r"(폴더|클립|문장|단어|투표|그룹|영상)을")
              .firstMatch(lines[i])!
              .group(1)!;
          // 받침이 있는 말(클립·문장·단어·그룹·영상)은 '을'이 맞다.
          if (m == '폴더' || m == '투표') {
            offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: "'폴더를'·'투표를'로 적으세요.");
  });
}
