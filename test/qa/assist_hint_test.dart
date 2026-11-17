// 자동 채우기가 막혔으면 그 자리에서 까닭을 말한다(5차 475).
//
// 단어 화면에서 고친 것(474)이 문장 화면에 그대로 남아 있었다. 같은 일을
// 두 화면이 다른 말로 하지 않도록 글귀도 한 곳에서 꺼내 쓴다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';

String _sourceOf(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('아직 안 적었을 때의 안내를 한 꼴로 만든다', () {
    expect(assistNeedsTextHint('문장'), '문장을 적으면 채울 수 있어요');
    expect(assistNeedsTextHint('단어'), '단어를 적으면 채울 수 있어요');
  });

  test('다 썼다는 말을 두 화면이 함께 쓴다', () {
    expect(assistQuotaExhaustedMessage, contains('내일'));
    const paths = [
      'lib/features/home/dashboard/presentation/add_sentence_screen.dart',
      'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
    ];
    for (final path in paths) {
      final src = _sourceOf(path);
      expect(src.contains('assistQuotaExhaustedMessage'), isTrue, reason: path);
      // 예전에 갈려 있던 말이 돌아오지 않는다.
      expect(src.contains("'오늘 횟수를 모두 썼어요"), isFalse, reason: path);
    }
  });

  test('문장 화면도 아직 안 적었으면 까닭을 적는다', () {
    final src = _sourceOf(
        'lib/features/home/dashboard/presentation/add_sentence_screen.dart');
    expect(src.contains("assistNeedsTextHint('문장')"), isTrue);
  });
}
