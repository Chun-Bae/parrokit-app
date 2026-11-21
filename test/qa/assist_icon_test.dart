// 뜻·발음과 예문 그림(5차 544, 사용자 요청).
//
// 패롯·크래커처럼 한 그림으로 맞춘다. 파일 이름을 잘못 적으면 화면에서는
// 빈 자리로만 보이고 테스트도 안 깨지므로, 파일이 실제로 있는지 본다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/assist_icon.dart';

void main() {
  test('그림 파일이 실제로 있다', () {
    for (final kind in AssistKind.values) {
      expect(File(kind.asset).existsSync(), isTrue,
          reason: '${kind.name}: ${kind.asset}가 없다');
    }
  });

  test('pubspec이 그 폴더를 싣는다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final kind in AssistKind.values) {
      final dir = '${kind.asset.substring(0, kind.asset.lastIndexOf('/'))}/';
      expect(pubspec.contains(dir), isTrue, reason: '$dir가 assets에 없다');
    }
  });

  test('두 그림은 서로 다른 파일을 쓴다', () {
    final assets = {for (final k in AssistKind.values) k.asset};
    expect(assets.length, AssistKind.values.length);
  });
}
