// 같은 크기를 화면마다 다르게 적지 않는다(5차 477).
//
// 더보기의 '임시 파일'은 '17.9 MB', 저장 용량 시트는 같은 값을 '18 MB'로
// 적고 있었다. CacheService가 제 포맷 함수를 따로 들고 있었던 탓이다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/format_bytes.dart';

void main() {
  test('10 이상이면 소수점을 떼고 그보다 작으면 한 자리 남긴다', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(980), '980 B');
    expect(formatBytes(1434), '1.4 KB');
    expect(formatBytes(18 * 1024 * 1024), '18 MB');
    // 17.9MB는 10 이상이라 소수점을 뗀다. 두 화면이 같은 값을 적는다.
    expect(formatBytes((17.9 * 1024 * 1024).round()), '18 MB');
  });

  test('크기를 적는 함수가 하나뿐이다', () {
    final cache = File('lib/core/infrastructure/services/cache_service.dart')
        .readAsStringSync();
    expect(cache.contains('String formatSize('), isFalse,
        reason: 'CacheService가 제 포맷 함수를 다시 들고 있으면 또 갈라진다');

    final data = File(
            'lib/features/settings/more/presentation/sections/data_section.dart')
        .readAsStringSync();
    expect(data.contains('formatBytes('), isTrue);
  });
}
