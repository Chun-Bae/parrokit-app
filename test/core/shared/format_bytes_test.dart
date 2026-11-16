// 크기 표시(5차 363).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/format_bytes.dart';

void main() {
  test('0 이하는 0 B', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(-5), '0 B');
  });

  test('바이트는 소수점 없이', () {
    expect(formatBytes(980), '980 B');
  });

  test('10보다 작으면 한 자리까지', () {
    expect(formatBytes(1536), '1.5 KB');
  });

  test('10 이상이면 소수점을 뗀다', () {
    expect(formatBytes(12 * 1024 * 1024), '12 MB');
  });

  test('GB에서 멈춘다', () {
    expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
  });
}
