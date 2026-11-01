import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/speech/phrase_recognizer.dart';

void main() {
  test('iOS dBFS 값은 조용하면 0, 말하면 높게 나온다', () {
    expect(normalizeSoundLevel(double.negativeInfinity, ios: true), 0);
    expect(normalizeSoundLevel(-61.2, ios: true), 0);
    expect(normalizeSoundLevel(-42.5, ios: true), lessThan(0.25));
    expect(normalizeSoundLevel(-20, ios: true), greaterThan(0.7));
    expect(normalizeSoundLevel(0, ios: true), 1);
  });

  test('Android 값은 -2~10 범위를 0~1로 맞춘다', () {
    expect(normalizeSoundLevel(-2, ios: false), 0);
    expect(normalizeSoundLevel(10, ios: false), 1);
  });
}
