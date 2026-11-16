// 자동 자막을 시작하기 전에 '이 영상에 몇 패롯이 드는지' 알려 준다(5차).
// 예전에는 '10초당 1패롯 소모'라는 비율만 적혀 있어 세어 봐야 알았다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/presentation/providers/captioning_provider.dart';

void main() {
  test('영상 길이를 알면 드는 패롯 수를 적는다', () {
    // 10초에 1패롯, 올림(서버 captionCost와 같은 식).
    expect(sttCostLine(8000), '이 영상은 1패롯 들어요 · 10초에 1패롯');
    expect(sttCostLine(61000), '이 영상은 7패롯 들어요 · 10초에 1패롯');
  });

  test('길이를 아직 모르면 비율만 적는다', () {
    expect(sttCostLine(null), '10초에 1패롯 들어요');
    expect(sttCostLine(0), '10초에 1패롯 들어요');
  });

  group('패롯이 모자랄 때', () {
    test('몇 개가 더 있어야 하는지 적는다', () {
      // 61초 → 7패롯. 가진 것은 2개.
      expect(sttShortOfParrotsLine(durationMs: 61000, coins: 2),
          '지금 패롯이 2개예요. 5개가 더 있어야 해요.');
    });

    test('넉넉하거나 길이를 모르면 아무 말도 안 한다', () {
      expect(sttShortOfParrotsLine(durationMs: 61000, coins: 7), isNull);
      expect(sttShortOfParrotsLine(durationMs: null, coins: 0), isNull);
    });
  });

  test('시작 창이 그 줄을 쓴다', () {
    final code = File(
            'lib/features/content-studio/captioning/presentation/widgets/stt_confirm_dialog.dart')
        .readAsStringSync();
    expect(code, contains('sttCostLine(vm.videoDurationMs)'));
    expect(code, contains('sttShortOfParrotsLine('));
    // 예전 비율만 적던 글은 사라졌다.
    expect(code.contains("'10초당 1패롯 소모'"), isFalse);
  });
}
