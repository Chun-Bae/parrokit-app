// 같은 일을 하는 단추는 같은 말을 쓴다(5차 555, 사용자 지적).
//
// 문장 쪽은 '뜻·발음·원문 생성'으로 맞췄는데 단어 쪽만 '채우기'로 남아
// 있었다. 화면마다 손으로 적어 두면 또 갈라진다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';

const _wordScreens = [
  'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
  'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
];

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('이름은 모두 생성으로 끝난다', () {
    expect(fillBasicsLabel, endsWith('생성'));
    expect(wordFillBasicsLabel, endsWith('생성'));
    expect(wordFillExamplesLabel, endsWith('생성'));
  });

  test('단어 쪽은 원문을 말하지 않는다', () {
    // 낱말이 재료라 만드는 것은 뜻과 발음뿐이다.
    expect(wordFillBasicsLabel.contains('원문'), isFalse);
  });

  test('단어 화면은 글자를 박아 두지 않는다', () {
    for (final path in _wordScreens) {
      final code = _code(path);
      expect(code.contains("Text('뜻·발음 채우기')"), isFalse, reason: path);
      expect(code.contains("Text('예문 채우기')"), isFalse, reason: path);
      expect(code.contains('wordFillBasicsLabel'), isTrue, reason: path);
      expect(code.contains('wordFillExamplesLabel'), isTrue, reason: path);
    }
  });

  test('단어 단추도 재화와 같은 그림을 쓴다', () {
    for (final path in _wordScreens) {
      final code = _code(path);
      expect(code.contains('AssistIcon(AssistKind.meaning'), isTrue,
          reason: path);
      expect(code.contains('AssistIcon(AssistKind.example'), isTrue,
          reason: path);
    }
  });
}
