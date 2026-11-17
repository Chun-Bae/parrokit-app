// 공유 문장 카드·상세의 '가져간 수'(5차 458).
//
// 아이콘 옆 숫자가 무슨 수인지 화면에 없었다. 목록 툴팁은 폰에서 길게
// 눌러야 떠서 사실상 안 보였고, 상세에는 툴팁조차 없었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shared/shared_sentence_stats.dart';

const _preview =
    'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';

String _code() => File(_preview)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('아무도 안 가져갔으면 적지 않는다', () {
    expect(importedByLabel(0), isNull);
    expect(importedByLabel(-1), isNull);
  });

  test('가져간 사람이 있으면 숫자의 뜻을 말로 적는다', () {
    expect(importedByLabel(1), '지금까지 1명이 내 문장으로 가져갔어요');
    expect(importedByLabel(12), '지금까지 12명이 내 문장으로 가져갔어요');
  });

  test('목록과 상세가 같은 툴팁을 쓴다', () {
    expect(importCountTooltip, '가져간 사람 수');
    final code = _code();
    // 글귀를 화면 안에 직접 적지 않는다.
    expect(code.contains("message: '가져간 사람 수'"), isFalse);
    expect('message: importCountTooltip'.allMatches(code).length, 2,
        reason: '목록 카드와 상세 둘 다');
  });

  test('상세가 가져오기 버튼 위에 그 줄을 보여 준다', () {
    final code = _code();
    expect(code, contains('detail-import-line'));
    expect(code, contains('importedByLabel(sharedImports)'));
  });
}
