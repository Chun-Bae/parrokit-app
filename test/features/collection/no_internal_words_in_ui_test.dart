// 화면 글에 내부 용어를 쓰지 않는다(5차).
//
// 보관함은 사용자에게 '폴더'라고 부르는데, 토스트와 메뉴 일부가 표(DB)의
// 이름인 '컬렉션'을 그대로 보여 주고 있었다('컬렉션을 지웠어요').
// 구간(세그먼트)은 clip_validator_message_test가 따로 지킨다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _uiStringPattern = RegExp(r"'([^'\\]{1,120})'");

/// 화면 글만 모은다(주석과 로그는 뺀다).
List<String> _uiStrings(String dir) {
  final found = <String>[];
  for (final file in Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || line.contains('AppLogger')) continue;
      for (final match in _uiStringPattern.allMatches(line)) {
        found.add('${file.path}  ${match.group(1)}');
      }
    }
  }
  return found;
}

void main() {
  test("보관함 화면은 '컬렉션'이 아니라 '폴더'라고 쓴다", () {
    final offenders = [
      ..._uiStrings('lib/features/collection'),
      ..._uiStrings('lib/features/home'),
    ].where((s) => s.contains('컬렉션')).toList();
    expect(offenders, isEmpty);
  });

  test("클립 편집 화면이 '메타데이터' 같은 개발 용어를 쓰지 않는다", () {
    // 버튼 이름이 '메타데이터'·'A-B 리스트'였다. 하나는 개발 용어이고
    // 하나는 반은 영어였다(5차). '파일 정보'·'구간 목록'으로 부른다.
    final offenders = _uiStrings('lib/features/content-studio/captioning')
        .where((s) => s.contains('메타데이터') || s.contains('A-B 리스트'))
        .toList();
    expect(offenders, isEmpty);
  });
}
