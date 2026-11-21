// 횟수를 묻는 동안 채우기 단추 아래 줄이 무엇을 적는지 지킨다(5차 519).
//
// 단추는 묻는 동안 막혀 있는데(5차 515) 그 아래 줄은 '한 번만 채우면 돼요',
// '겹치지 않는 예문을 받아요'라고 적혀 있었다. 서버가 쉬다 깨는 첫 조회는
// 30초 가까이 걸려서(시뮬레이터에서 봤다) 그 동안 고장으로 읽혔다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';

void main() {
  test('묻는 중이면 기다리는 중이라고 적는다', () {
    expect(
      assistFillHint(loading: true, whenReady: wordFillExamplesHint),
      assistUsageLoadingLabel,
    );
    expect(
      assistFillHint(loading: true, whenReady: wordFillBasicsHint),
      assistUsageLoadingLabel,
    );
  });

  test('다 물었으면 원래 말을 그대로 적는다', () {
    expect(
      assistFillHint(loading: false, whenReady: wordFillExamplesHint),
      wordFillExamplesHint,
    );
    expect(
      assistFillHint(loading: false, whenReady: assistQuotaExhaustedMessage),
      assistQuotaExhaustedMessage,
    );
  });

  test('고치기 시트의 두 줄이 모두 이 말을 쓴다', () {
    // 한쪽만 고치면 다른 단추가 또 까닭 없이 막힌 채로 남는다.
    final source = File(
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
    ).readAsStringSync();
    expect('assistFillHint('.allMatches(source).length, 2);
  });

  test('추가 시트의 예문 줄도 이 말을 쓴다', () {
    final source = File(
      'lib/features/collection/shell/presentation/widgets/'
      'word_collection_preview.dart',
    ).readAsStringSync();
    expect(source.contains('assistFillHint('), isTrue);
  });
}
