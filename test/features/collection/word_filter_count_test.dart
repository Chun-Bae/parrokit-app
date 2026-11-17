// 보관함 > 단어 탭의 개수와 거르기(5차 452).
//
// '직접 추가'로 거르면 목록은 두 개인데 머리줄은 '내 단어 6'이라 어느
// 쪽이 맞는지 알 수 없었다. 거른 결과가 비면 거르기를 풀 길도 없었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';

const _path =
    'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart';

String _code() => File(_path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('거르지 않으면 전체 수만 적는다', () {
    expect(wordCountLabel(shown: 6, all: 6, filtered: false), '6');
  });

  test('거르는 중이면 보이는 수와 전체 수를 함께 적는다', () {
    expect(wordCountLabel(shown: 2, all: 6, filtered: true), '2 / 6');
    // 거른 결과가 전체와 같아도 거르는 중이라는 것을 숨기지 않는다.
    expect(wordCountLabel(shown: 6, all: 6, filtered: true), '6 / 6');
  });

  test('머리줄이 걸러진 목록과 같은 수를 센다', () {
    final code = _code();
    expect(code, contains('shown: visible.length'));
    expect(code, contains('all: languageWords.length'));
    expect(code, contains('filtered: category != categories.first'));
  });

  test('거른 결과가 비면 거르기를 풀 길을 준다', () {
    expect(wordFilterClearLabel, '전체 보기');
    final code = _code();
    expect(code, contains('word-filter-clear'));
    expect(code, contains('category = categories.first'));
  });
}
