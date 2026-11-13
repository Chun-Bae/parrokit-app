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
}
