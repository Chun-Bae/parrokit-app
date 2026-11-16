// 실패 화면에는 그 자리에서 다시 해 볼 길이 있어야 한다(5차 394).
//
// 393에서 보관함 검색과 ElevenLabs 목소리 시트를 고쳤다. 같은 식으로
// 까닭만 적고 끝나는 자리가 세 곳 더 있었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// 주석을 뺀 코드 줄만.
String _code(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('쇼츠는 영상을 못 불러오면 다시 시도할 수 있다', () {
    final source = _read('lib/features/collection/clip/shorts/presentation/'
        'widgets/shorts_page.dart');
    expect(source.contains("ValueKey('shorts-retry')"), isTrue);
    // 다시 부르는 함수를 실제로 건다.
    expect(_code(source).contains('_initVideo();'), isTrue);
  });

  test('최근 본 클립은 당길 수 있는 실패 화면을 돌려준다', () {
    final source =
        _read('lib/features/home/recent/presentation/recent_screen.dart');
    final code = _code(source);
    expect(source.contains("ValueKey('recent-retry')"), isTrue);
    // 당기라고 적어 두고 스크롤되지 않는 화면을 주지 않는다.
    expect(code.contains('아래로 당겨 다시 시도해 주세요'), isFalse);
    expect(code.contains('AlwaysScrollableScrollPhysics'), isTrue);
  });

  test('문장 탭의 둘러보기 줄도 다시 불러올 수 있다', () {
    final source = _read('lib/features/collection/shell/presentation/'
        'widgets/sentence_collection_preview.dart');
    expect(source.contains("ValueKey('explore-strip-retry')"), isTrue);
    // 아래 목록과 같은 말을 쓴다.
    expect("'다시 불러오기'".allMatches(source).length, greaterThanOrEqualTo(2));
  });
}
