// 문장은 200자까지 쓸 수 있다(5차, 사용자 요청: 80 → 200).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/add_sentence_controller.dart';

void main() {
  test('한도는 200자이고 화면이 그 값을 쓴다', () {
    expect(sentenceMaxLength, 200);
    final code = File(
            'lib/features/home/dashboard/presentation/add_sentence_screen.dart')
        .readAsStringSync();
    expect(code, contains('maxLength: sentenceMaxLength'));
    expect(code.contains('maxLength: 80'), isFalse);
  });
}
