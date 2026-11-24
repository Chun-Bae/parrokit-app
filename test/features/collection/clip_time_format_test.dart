import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/player/presentation/clip_time_format.dart';

void main() {
  test('플레이어 시각은 영상 앱처럼 분:초로 보인다', () {
    expect(clipClock(0), '0:00');
    expect(clipClock(3999), '0:03');
    expect(clipClock(65000), '1:05');
    expect(clipClock(3725000), '1:02:05');
    expect(clipClock(-5), '0:00');
  });

  test('구간은 2초 이상이면 초까지, 짧으면 0.1초까지 보인다', () {
    expect(segmentRangeLabel(3000, 7400), '0:03 – 0:07');
    expect(segmentRangeLabel(0, 500), '0:00.0 – 0:00.5');
    expect(segmentRangeLabel(61200, 62900), '1:01.2 – 1:02.9');
  });

  test('2초보다 짧은 클립은 재생 시계도 0.1초까지 보인다', () {
    // 1.4초짜리 클립을 초로만 적으면 재생 내내 '0:01 / 0:01'이라 숫자가
    // 멈춰 보였다. 구간 칩은 '0:00.0 - 0:01.4'로 적어서 구간 끝이 전체
    // 길이보다 뒤에 있는 것처럼 보이기도 했다(5차).
    expect(clipPlayClock(700, totalMs: 1400), '0:00.7');
    expect(clipPlayClock(1400, totalMs: 1400), '0:01.4');
    // 재생이 흐르면 숫자도 흐른다. 예전엔 셋 다 '0:01'이었다.
    final ticks = [1000, 1100, 1200]
        .map((ms) => clipPlayClock(ms, totalMs: 1400))
        .toSet();
    expect(ticks.length, 3);
  });

  test('구간 재생이면 구간 길이로 0.1초까지를 가른다', () {
    // 8초짜리 영상 안의 1.2초 구간을 돌리면, 칩은 '0:01.2 – 0:02.4'인데
    // 시계는 '0:01 / 0:08'이었다(5차). 한 화면에서 두 잣대가 엇갈렸고,
    // 구간을 도는 내내 시계는 '0:01'과 '0:02' 둘만 오갔다.
    expect(segmentRangeLabel(1200, 2400), '0:01.2 – 0:02.4');
    expect(clipPlayClock(1200, totalMs: 8000, segmentMs: 1200), '0:01.2');
    expect(clipPlayClock(2400, totalMs: 8000, segmentMs: 1200), '0:02.4');
    // 구간을 도는 동안 숫자가 흐른다. 예전엔 넷 다 '0:01'이었다.
    final ticks = [1200, 1500, 1800, 1900]
        .map((ms) => clipPlayClock(ms, totalMs: 8000, segmentMs: 1200))
        .toSet();
    expect(ticks.length, 4);
  });

  test('구간이 2초 이상이면 구간 재생이어도 초만 보인다', () {
    // 칩도 '0:01 – 0:04'로 적는다. 같은 잣대를 쓴다.
    expect(segmentRangeLabel(1000, 4000), '0:01 – 0:04');
    expect(clipPlayClock(2500, totalMs: 8000, segmentMs: 3000), '0:02');
  });

  test('2초 넘는 클립은 예전처럼 초만 보인다', () {
    // 긴 영상은 끝자리가 계속 바뀌어 읽기만 어렵다.
    expect(clipPlayClock(3999, totalMs: 8000), '0:03');
    expect(clipPlayClock(2000, totalMs: 2000), '0:02');
    expect(clipPlayClock(65000, totalMs: 120000), '1:05');
  });

  test('전체 재생이면 구간 길이를 보지 않는다', () {
    // segmentMs를 주지 않으면 예전 그대로 영상 길이로 가른다.
    expect(clipPlayClock(1200, totalMs: 8000), '0:01');
    expect(clipPlayClock(700, totalMs: 1400), '0:00.7');
  });
}
