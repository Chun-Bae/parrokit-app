// 앱을 내렸다 돌아왔을 때 영상을 맞출 자리(5차, 사용자 신고).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/player/domain/resume_target.dart';

Duration target({
  required Duration position,
  bool segmentScope = false,
  Duration segmentStart = const Duration(seconds: 2),
  Duration segmentEnd = const Duration(seconds: 5),
  Duration duration = const Duration(seconds: 8),
}) =>
    resumeTargetAfterBackground(
      position: position,
      segmentScope: segmentScope,
      segmentStart: segmentStart,
      segmentEnd: segmentEnd,
      duration: duration,
    );

void main() {
  group('전체 재생', () {
    test('듣던 자리를 그대로 쓴다', () {
      expect(target(position: const Duration(seconds: 3)),
          const Duration(seconds: 3));
    });

    test('끝에 닿았으면 처음으로 돌린다', () {
      // 끝에 붙은 채 멈춰 있었다. 재생을 눌러도 이미 끝이라 아무 일도 없었다.
      expect(target(position: const Duration(seconds: 8)), Duration.zero);
      expect(target(position: const Duration(milliseconds: 7900)),
          Duration.zero, reason: '0.2초 못 미친 자리도 끝으로 본다');
      expect(target(position: const Duration(seconds: 9)), Duration.zero,
          reason: '길이를 넘겨 와도 처음으로');
    });

    test('끝보다 넉넉히 앞이면 그대로', () {
      expect(target(position: const Duration(milliseconds: 7700)),
          const Duration(milliseconds: 7700));
    });

    test('길이를 모르면 받은 자리를 그대로 쓴다', () {
      expect(
          target(position: const Duration(seconds: 8), duration: Duration.zero),
          const Duration(seconds: 8));
    });
  });

  group('구간 재생', () {
    test('구간 안이면 그대로', () {
      expect(target(position: const Duration(seconds: 3), segmentScope: true),
          const Duration(seconds: 3));
    });

    test('구간 앞뒤면 구간 처음으로', () {
      expect(target(position: const Duration(seconds: 1), segmentScope: true),
          const Duration(seconds: 2));
      expect(target(position: const Duration(seconds: 5), segmentScope: true),
          const Duration(seconds: 2), reason: '구간 끝은 구간 밖으로 본다');
      expect(target(position: const Duration(seconds: 7), segmentScope: true),
          const Duration(seconds: 2));
    });

    test('구간 재생은 영상 끝 규칙을 쓰지 않는다', () {
      expect(
          target(
              position: const Duration(seconds: 4, milliseconds: 900),
              segmentScope: true),
          const Duration(seconds: 4, milliseconds: 900));
    });
  });

  test('음수가 와도 안전하다', () {
    expect(target(position: const Duration(seconds: -1)), Duration.zero);
    expect(target(position: const Duration(seconds: -1), segmentScope: true),
        const Duration(seconds: 2));
  });
}
