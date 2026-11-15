// 저장 위치를 부르는 말(5차).
//
// 같은 곳을 목록 배지는 '로컬'·'클라우드 · Google Drive', 옮기기 시트는
// '로컬'·'Google Drive', 저장 용량은 '로컬'이라 불렀다. 화면마다 달라서
// 어디에 있는 클립인지 헷갈렸다. '기기 · 서버 · Google Drive'로 맞춘다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _files = [
  'lib/features/collection/library/presentation/widgets/clip_list_view.dart',
  'lib/features/collection/library/presentation/widgets/storage_scope_tabs.dart',
  'lib/features/collection/library/presentation/widgets/storage_transfer_sheet.dart',
  'lib/features/collection/library/presentation/clip_library_home.dart',
  'lib/features/home/dashboard/presentation/widgets/collection_card.dart',
  'lib/features/settings/more/presentation/sections/remote_storage_section.dart',
];

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test("화면 글에 '로컬'·'클라우드'를 쓰지 않는다", () {
    for (final path in _files) {
      final code = _code(path);
      expect(code.contains("'로컬'"), isFalse, reason: path);
      expect(code.contains("'클라우드'"), isFalse, reason: path);
      expect(code.contains('클라우드 · Google Drive'), isFalse, reason: path);
    }
  });

  test('클립 칩·거르개·폴더 카드가 같은 상태 말을 쓴다', () {
    // 228부터 위치 이름이 아니라 상태로 적는다. 말이 한 곳(storageStateLabel)에
    // 모여 있어야 화면마다 어긋나지 않는다.
    for (final path in [
      'lib/features/collection/library/presentation/widgets/clip_list_view.dart',
      'lib/features/collection/library/presentation/clip_library_home.dart',
      'lib/features/home/dashboard/presentation/widgets/collection_card.dart',
    ]) {
      final code = _code(path);
      expect(code, contains('storageStateLabel('), reason: path);
      expect(code.contains("'Google Drive'"), isFalse, reason: path);
    }
  });
}
