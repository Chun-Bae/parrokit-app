// 폴더 이름을 만들 수 없을 때 까닭을 말한다(5차 316).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/library/presentation/folder_name_rules.dart';

String _flat(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('빈 이름, 슬래시, 그대로인 이름을 가려낸다', () {
    expect(folderNameBlockedReason(''), '폴더 이름을 적어 주세요.');
    expect(folderNameBlockedReason('   '), '폴더 이름을 적어 주세요.');
    expect(folderNameBlockedReason('영어/회화'), contains("'/'"));
    expect(
        folderNameBlockedReason('일상회화',
            renaming: true, initialName: '일상회화'),
        contains('그대로'));
  });

  test('쓸 수 있는 이름이면 막지 않는다', () {
    expect(folderNameBlockedReason('일상회화'), isNull);
    expect(
        folderNameBlockedReason('새 이름',
            renaming: true, initialName: '일상회화'),
        isNull);
    // 앞뒤 공백만 다른 것은 그대로로 본다.
    expect(
        folderNameBlockedReason(' 일상회화 ',
            renaming: true, initialName: '일상회화'),
        contains('그대로'));
  });

  test('폴더 창은 꺼진 채 두지 않고 까닭을 적는다', () {
    final code = _flat(
        'lib/features/collection/library/presentation/folder_picker_sheet.dart');
    expect(code, contains('onPressed: _submit'));
    expect(code, contains("ValueKey('folder-name-hint')"));
    expect(code, contains('folderNameBlockedReason('));
  });

  test('문장 가져오기도 하나도 안 골랐을 때 까닭을 알린다', () {
    final code = _flat(
        'lib/features/collection/shell/presentation/widgets/sentence_import_sheet.dart');
    // 바텀시트라 토스트는 가려진다. 시트 안에 적는다(5차 369).
    expect(code, contains("ValueKey('import-pick-hint')"));
    expect(code, contains('_showPickHint = true'));
    expect(code.contains('onPressed: _selected.isEmpty ? null : _start'), isFalse);
  });
}
