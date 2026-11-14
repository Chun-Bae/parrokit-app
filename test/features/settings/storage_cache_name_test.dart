// 받아 둔 영상 화면 이름(5차). 들어온 줄과 화면 제목이 같은 말을 쓴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('더보기의 줄 이름과 화면 제목이 같다', () {
    // 전에는 줄이 '보관 영상'(보관함 영상과 헷갈린다), 화면은 '기기 보관
    // 관리'였다.
    final entry = File(
            'lib/features/settings/more/presentation/sections/data_section.dart')
        .readAsStringSync();
    final screen = File(
            'lib/features/settings/more/presentation/storage_cache_management_screen.dart')
        .readAsStringSync();

    expect(entry, contains("label: '받아 둔 영상'"));
    expect(screen, contains("Text('받아 둔 영상')"));
    expect(entry.contains("label: '보관 영상'"), isFalse);
    expect(screen.contains("Text('기기 보관 관리')"), isFalse);
  });

  test('머리글이 무엇을 지우는지 말한다', () {
    final screen = File(
            'lib/features/settings/more/presentation/storage_cache_management_screen.dart')
        .readAsStringSync();
    expect(screen, contains('기기에 받아 둔 파일'));
    // 원본은 남는다는 것을 분명히 한다.
    expect(screen, contains('원본은 그대로'));
  });
}
