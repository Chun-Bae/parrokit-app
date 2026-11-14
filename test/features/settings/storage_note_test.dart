// 저장 용량 설명 글(5차). 칩과 같은 이름을 쓰고 앱 말투로 적는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _files = [
  'lib/features/settings/more/presentation/sections/remote_storage_section.dart',
  'lib/features/collection/library/presentation/sections/library_folder_section.dart',
];

void main() {
  test('설명이 칩과 같은 이름(Parrokit 폴더)을 쓴다', () {
    // 칩은 'Parrokit 91 KB'인데 설명만 'Parrokit가 차지하는 실제 크기'라
    // 무엇을 센 것인지 덜 분명했다. 그 이름은 Drive에 실제로 만드는 폴더
    // 이름이라 영문 그대로 둔다.
    for (final path in _files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('Parrokit 폴더'), reason: path);
      expect(source.contains('따로 분리해 보여줍니다'), isFalse, reason: path);
    }
  });

  test('설명이 앱 말투(~요)로 끝난다', () {
    for (final path in _files) {
      final source = File(path).readAsStringSync();
      for (final match
          in RegExp(r"'(Drive 전체[^']*)'").allMatches(source)) {
        expect(match.group(1), endsWith('요.'), reason: path);
      }
    }
  });
}
