// 저장 용량 설명 글(5차). 칩과 같은 이름을 쓰고 앱 말투로 적는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _files = [
  'lib/features/settings/more/presentation/sections/remote_storage_section.dart',
  'lib/features/collection/library/presentation/sections/library_folder_section.dart',
];

void main() {
  _deviceCardTests();
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

// '기기' 카드의 설명이 그 숫자와 맞는지(5차 498).
//
// 450에서 숫자에 임시 파일을 더했는데 설명은 '이 기기에 있어 오프라인에서도
// 열 수 있는 파일' 그대로였다. 기기 20 MB 가운데 17 MB가 임시 파일이라
// 묶음의 대부분에 대해 사실이 아니었다.
void _deviceCardTests() {
  const path =
      'lib/features/settings/more/presentation/sections/remote_storage_section.dart';

  String code() => File(path)
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('기기 카드 설명', () {
    test('임시 파일까지 더한 수라는 것과 맞는 말을 쓴다', () {
      expect(code(), contains('이 앱이 이 기기에서 쓰는 용량이에요'));
      expect(code().contains('오프라인에서도 열 수 있는 파일'), isFalse);
    });

    test('줄일 길을 알려 준다', () {
      expect(code(), contains('임시 파일은 정리할 수 있어요'));
    });

    test('나눠 적는 칩 셋은 그대로다', () {
      for (final chip in ['보관한 영상', '받아 둔 영상', '임시 파일']) {
        expect(code(), contains(chip), reason: chip);
      }
    });
  });
}
