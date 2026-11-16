// 문장 상세 시트의 알림은 시트 안에 보여야 한다(5차 390).
//
// 이 시트는 바텀시트로 뜬다. 공유·루틴·좋아요·단어 저장·따라 말하기 결과를
// SnackBar로 알리고 있었는데, SnackBar는 시트 뒤 화면 아래에 깔려
// 사용자 눈에 닿지 않았다(368~371에서 다른 시트들로 확인한 것과 같은 문제).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart' show WordAddResult;
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart'
    show wordAddResultText;

/// `_SentenceDetailSheetState` 클래스 몸통만 잘라 온다.
String _detailSheetStateBody() {
  final source = File(
    'lib/features/collection/shell/presentation/widgets/'
    'sentence_collection_preview.dart',
  ).readAsStringSync();
  const start = 'class _SentenceDetailSheetState';
  final from = source.indexOf(start);
  expect(from, greaterThan(0), reason: '상세 시트 상태 클래스를 찾지 못했다');
  final to = source.indexOf('\nclass ', from + start.length);
  return source.substring(from, to == -1 ? source.length : to);
}

void main() {
  test('상세 시트는 알릴 말을 시트 안에 적는다', () {
    final body = _detailSheetStateBody();
    expect(body.contains("ValueKey('sentence-detail-notice')"), isTrue,
        reason: '시트 안에 알림을 그리는 자리가 있어야 한다');
    expect(body.contains('void showNotice(String message)'), isTrue);
  });

  test('시트가 떠 있는 동안에는 SnackBar를 쓰지 않는다', () {
    final body = _detailSheetStateBody();
    final lines = body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains('ScaffoldMessenger')) continue;
      if (line.trimLeft().startsWith('//')) continue;
      // 남겨도 되는 것은 '시트를 닫고 알리는' 자리뿐이다. 바로 윗줄에 까닭을
      // 적어 두었다.
      final prev = i == 0 ? '' : lines[i - 1];
      expect(prev.contains('시트를 닫고 알리므로'), isTrue,
          reason: '시트가 떠 있는 채로 SnackBar를 띄우면 보이지 않는다: ${line.trim()}');
    }
  });

  test('단어 저장 결과 말은 한 곳에서 만든다', () {
    expect(wordAddResultText(WordAddResult.added), '단어를 저장했어요.');
    expect(wordAddResultText(WordAddResult.duplicate), '이미 저장한 단어예요.');
    expect(wordAddResultText(WordAddResult.savedOnDevice),
        '서버에 저장하지 못해 이 기기에 저장했어요.');
  });
}
