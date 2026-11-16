// 구간 카드의 A·B 단추(5차).
//
// 이 단추는 **지금 보고 있는 자리**를 구간의 시작·끝에 넣는다. 그런데 아래
// 글이 '추가'라, 바로 옆의 '+ 추가'(구간을 하나 더 만들기)와 같은 일처럼
// 읽혔다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _card =
    'lib/features/content-studio/captioning/presentation/widgets/segment_card.dart';

String _code() => File(_card)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test("A·B 아래 글은 '추가'가 아니라 '지금'이다", () {
    final code = _code();
    expect(code, contains("'지금'"));
    expect(code.contains("          '추가',"), isFalse);
  });

  test('길게 누르거나 화면 읽기로 무엇을 하는지 알 수 있다', () {
    final code = _code();
    expect(code, contains("hint: '지금 보고 있는 자리를 시작으로'"));
    expect(code, contains("hint: '지금 보고 있는 자리를 끝으로'"));
    expect(code, contains('Tooltip('));
    expect(code, contains("label: '\$symbol, \$hint'"));
  });

  test('구간을 더하는 단추는 그대로 + 추가다', () {
    // 두 단추가 같은 말을 쓰면 다시 헷갈린다.
    final tabs = File(
            'lib/features/content-studio/captioning/presentation/sections/segments_section.dart')
        .readAsStringSync();
    expect(tabs, contains("label: '+ 추가'"));
  });
}
