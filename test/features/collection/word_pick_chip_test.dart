// 문장 상세에서 단어를 고르는 칩 이름(5차).
//
// 단어 탭은 '직접 추가'라 부르는데 문장 상세의 같은 일을 하는 칩만
// '직접 입력'이었다. 안내 말투도 '입력해주세요'로 달랐다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('문장 상세의 단어 칩이 단어 탭과 같은 말을 쓴다', () {
    final detail = _code(
      'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart',
    );
    expect(detail, contains("const Text('직접 추가')"));
    expect(detail.contains("const Text('직접 입력')"), isFalse);
  });

  test('문장 추가 화면 안내가 앱 말투를 쓴다', () {
    final add = _code(
      'lib/features/home/dashboard/presentation/add_sentence_screen.dart',
    );
    expect(add.contains('입력해주세요'), isFalse);
    expect(add, contains('직접 적어 주세요'));
  });
}
