// 패롯을 쓰기 전에 모자람을 알리는 말은 한 곳에서 정한다(5차).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/parrot_cost_text.dart';

void main() {
  test('모자라면 몇 개가 더 있어야 하는지 적는다', () {
    expect(parrotShortfallLine(cost: 7, coins: 2),
        '지금 패롯이 2개예요. 5개가 더 있어야 해요.');
  });

  test('넉넉하거나 값이 0이면 아무 말도 안 한다', () {
    expect(parrotShortfallLine(cost: 7, coins: 7), isNull);
    expect(parrotShortfallLine(cost: 7, coins: 9), isNull);
    expect(parrotShortfallLine(cost: 0, coins: 0), isNull);
  });

  test('패롯을 쓰는 두 화면이 같은 말을 쓴다', () {
    // 값을 치르는 자리마다 따로 적다가 한쪽만 고쳐진 적이 많았다.
    for (final path in [
      'lib/features/content-studio/captioning/presentation/providers/captioning_provider.dart',
      'lib/features/content-studio/tts/presentation/screens/tts_screen.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('parrotShortfallLine('),
          reason: path);
    }
  });
}
