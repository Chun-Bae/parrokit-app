// 거른 목록인데 머리줄이 전체를 세지 않는다(5차 483).
//
// 단어 탭에서 452에 고친 결함이 클립 탭에 그대로 남아 있었다. 태그
// '#토익'으로 걸러 한 개만 보이는데 머리줄은 '모든 클립 5개'였다.
// 셈을 한 곳에 두고 두 화면이 함께 쓴다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/filtered_count_label.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('거르는 중이면 보이는 수와 전체 수를 함께 적는다', () {
    expect(filteredCountLabel(shown: 1, all: 5, filtered: true, suffix: '개'),
        '1 / 5개');
    expect(filteredCountLabel(shown: 5, all: 5, filtered: false, suffix: '개'),
        '5개');
    expect(filteredCountLabel(shown: 2, all: 6, filtered: true), '2 / 6');
    expect(filteredCountLabel(shown: 6, all: 6, filtered: false), '6');
  });

  test('클립 탭 머리줄이 거른 수를 쓴다', () {
    final code =
        _code('lib/features/collection/library/presentation/clip_library_home.dart');
    expect(code, contains('filteredCountLabel('));
    // 전체 수를 그대로 적던 옛 꼴이 돌아오지 않는다.
    expect(code.contains(r"trailing: '${_clips.length}개'"), isFalse);
    expect(code.contains(r"trailing: '${_openFolder!.directCount}개'"), isFalse);
  });

  test('단어 탭도 같은 셈을 쓴다', () {
    final code = _code('lib/features/collection/shell/presentation/'
        'widgets/word_collection_preview.dart');
    expect(code, contains('filteredCountLabel('));
  });
}
