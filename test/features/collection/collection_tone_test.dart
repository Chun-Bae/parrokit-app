// 보관함·홈·더보기 화면도 '삭제' 대신 '지우기'로 말한다(5차 402).
//
// 커뮤니티는 327에서 통일했는데 보관함·설정 쪽에 '삭제하면 ...',
// '그룹 삭제', '내 문장에서 삭제'처럼 예전 말이 남아 있었다. 같은 일을
// 화면마다 다른 말로 부르면 무엇이 다른 일인지 헷갈린다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 화면에 그리는 작은따옴표 글만 모은다(주석과 로그 줄은 뺀다).
Iterable<String> _uiStrings(String path) {
  final lines = File(path).readAsLinesSync();
  final out = <String>[];
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//')) continue;
    if (trimmed.contains('AppLogger')) continue;
    for (final m in RegExp(r"'([^']*)'").allMatches(line)) {
      out.add(m.group(1)!);
    }
  }
  return out;
}

const _dirs = [
  'lib/features/collection',
  'lib/features/home',
  'lib/features/settings',
];

Iterable<File> _dartFiles() sync* {
  for (final dir in _dirs) {
    for (final entity in Directory(dir).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) yield entity;
    }
  }
}

void main() {
  test("화면 글에 '삭제'가 남아 있지 않다", () {
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      for (final text in _uiStrings(file.path)) {
        if (text.contains('삭제')) offenders.add('${file.path}: $text');
      }
    }
    expect(offenders, isEmpty,
        reason: "앱은 '지우기'라고 말한다:\n${offenders.join('\n')}");
  });
}
