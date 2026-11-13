import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/domain/utils/timecode_service.dart';
import 'package:parrokit/features/content-studio/captioning/domain/validators/clip_validator.dart';

void main() {
  final tc = TimecodeService();

  test('밀리초를 MM:SS.mmm으로 채워 쓴다', () {
    expect(tc.msToMMSSmmm(0), '00:00.000');
    expect(tc.msToMMSSmmm(7), '00:00.007');
    expect(tc.msToMMSSmmm(61005), '01:01.005');
    expect(tc.msToMMSSmmm(59999), '00:59.999');
  });

  test('MM:SS.mmm을 밀리초로 읽는다', () {
    expect(tc.parseToMs('00:00.000'), 0);
    expect(tc.parseToMs('01:01.005'), 61005);
    expect(tc.parseToMs('04:59.999'), 299999);
  });

  test('클립 최대 길이(5분)까지 모든 초가 쓰고 읽어도 같다', () {
    for (var ms = 0; ms <= ClipValidator.maxDurationMs; ms += 997) {
      final text = tc.msToMMSSmmm(ms);
      expect(TimecodeService.mmssmmm.hasMatch(text), isTrue, reason: text);
      expect(ClipValidator.timecodePattern.hasMatch(text), isTrue,
          reason: text);
      expect(tc.parseToMs(text), ms);
    }
    final end = tc.msToMMSSmmm(ClipValidator.maxDurationMs);
    expect(end, '05:00.000');
    expect(tc.parseToMs(end), ClipValidator.maxDurationMs);
  });

  test('모양이 틀린 글은 예외를 낸다(부르는 쪽이 잡아 null로 바꾼다)', () {
    for (final bad in ['', '1:00.000', '00:00', '00:00.00', 'ab:cd.efg']) {
      expect(() => tc.parseToMs(bad), throwsA(anything), reason: bad);
      expect(TimecodeService.mmssmmm.hasMatch(bad), isFalse, reason: bad);
    }
  });
}
