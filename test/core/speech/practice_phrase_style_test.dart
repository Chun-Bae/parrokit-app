// 긴 문장도 따라 말할 수 있게 글자만 줄인다(5차 325).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/speech/presentation/speech_practice_view.dart';

void main() {
  test('짧은 문장은 큰 글씨 그대로', () {
    expect(compactPracticePhrase('Can I get a latte, please?'), isFalse);
  });

  test('긴 문장은 작은 글씨로', () {
    expect(compactPracticePhrase('A' * 81), isTrue);
    expect(compactPracticePhrase('A' * 200), isTrue);
  });

  test('자르지는 않는다', () {
    // 따라 말하려면 문장을 다 봐야 한다. maxLines·ellipsis를 쓰지 않는다.
    final code = File('lib/core/speech/presentation/speech_practice_view.dart')
        .readAsStringSync();
    expect(code.contains('ellipsis'), isFalse);
    expect(code, contains('compactPracticePhrase(widget.phrase)'));
  });
}
