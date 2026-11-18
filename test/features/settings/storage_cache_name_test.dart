// 받아 둔 영상 화면 이름(5차, 497에서 갱신).
//
// 들어온 줄·화면 제목·맨 위 카드가 한 말을 쓴다. 전에는 줄이 '보관 영상'
// (보관함 영상과 헷갈린다), 화면이 '기기 보관 관리'였고, 그 둘을 맞춘 뒤에도
// 맨 위 카드만 '기기에 받아 둔 파일'이라 불렀다(497).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/storage_cache_management_screen.dart';

const _screenPath =
    'lib/features/settings/more/presentation/storage_cache_management_screen.dart';
const _entryPath =
    'lib/features/settings/more/presentation/sections/data_section.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('들어온 줄·화면 제목·맨 위 카드가 같은 말을 쓴다', () {
    expect(cachedScreenTitle, '받아 둔 영상');

    final entry = _code(_entryPath);
    expect(entry, contains("label: '받아 둔 영상'"));
    expect(entry.contains("label: '보관 영상'"), isFalse);

    final screen = _code(_screenPath);
    // 제목과 카드가 둘 다 상수를 꺼내 쓴다.
    expect(screen, contains('Text(cachedScreenTitle)'));
    expect(screen, contains('cachedScreenTitle,'));
    expect(screen.contains("Text('기기 보관 관리')"), isFalse);
    // 카드 제목이 '파일'로 돌아가지 않는다.
    expect(screen.contains("'기기에 받아 둔 파일',"), isFalse);
  });

  test('머리글이 무엇을 지우는지 말한다', () {
    final screen = _code(_screenPath);
    // 설명문은 원본과 견주는 자리라 '받아 둔 파일'을 그대로 쓴다.
    expect(screen, contains('기기에 받아 둔 파일만 지워요'));
    expect(screen, contains('원본은 그대로'));
  });

  test("크기 줄이 '보관'이라 부르지 않는다", () {
    // 저장 용량 시트의 '보관한 영상'은 이 기기에 둔 클립 원본이라 다른
    // 것이다. 여기 숫자는 받아 둔 것만 센다(5차 497).
    final screen = _code(_screenPath);
    expect(screen, contains('받아 둔 용량:'));
    expect(screen.contains('보관 용량:'), isFalse);

    final sheet = _code('lib/features/settings/more/presentation/'
        'sections/remote_storage_section.dart');
    expect(sheet, contains('보관한 영상'));
  });
}
