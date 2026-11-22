// 임시 파일 크기를 두 화면이 같게 보는지 지킨다(5차 565).
//
// 더보기의 '임시 파일' 칸과 저장 용량 시트가 각자 제 시점에 재면, 그 사이에
// 임시 파일이 늘었을 때 한 화면 안에서 '34 MB'와 '38 MB'가 같이 보인다.
// 자동 자막을 한 번 만들면 바로 그렇게 됐다. 잰 값은 CacheService가
// 하나로 들고 있어야 한다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/cache_service.dart';

void main() {
  test('잰 값을 한 곳에 들고 있다', () {
    expect(CacheService.instance.sizeBytes, isNotNull);
  });

  final service =
      File('lib/core/infrastructure/services/cache_service.dart')
          .readAsStringSync();
  final dataSection = File(
    'lib/features/settings/more/presentation/sections/data_section.dart',
  ).readAsStringSync();
  final sheet = File(
    'lib/features/settings/more/presentation/sections/'
    'remote_storage_section.dart',
  ).readAsStringSync();

  test('잴 때마다 그 값을 적어 둔다', () {
    expect(service.contains('sizeBytes.value = totalSize'), isTrue);
  });

  test('정리하면 0으로 둔다', () {
    expect(service.contains('sizeBytes.value = 0'), isTrue);
  });

  test('더보기 칸은 제 값을 따로 두지 않는다', () {
    expect(dataSection.contains('CacheService.instance.sizeBytes'), isTrue);
    expect(dataSection.contains("String _cacheSize = ''"), isFalse,
        reason: '제 상태에 담아 두면 시트와 어긋난다');
  });

  test('저장 용량 시트도 같은 값을 듣는다', () {
    expect(sheet.contains('CacheService.instance.sizeBytes.addListener'),
        isTrue);
    expect(sheet.contains('removeListener'), isTrue, reason: '떼지 않으면 샌다');
  });
}
