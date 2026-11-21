// 복습을 끝내지 않고 창을 닫으면 몇 문제를 풀었는지 알린다(5차 515, 사용자 요청).
//
// 고른 답은 그때그때 저장되는데, 중간에 시트를 내리면 아무 말이 없어서
// 한 것이 날아간 줄 알기 쉬웠다. 한 문제도 안 풀었으면 알릴 것이 없다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';

void main() {
  test('한 문제도 안 풀었으면 알리지 않는다', () {
    expect(wordReviewPartialMessage(0), isNull);
    expect(wordReviewPartialMessage(-1), isNull);
  });

  test('푼 만큼 적는다', () {
    expect(wordReviewPartialMessage(1), '1문제 풀었어요');
    expect(wordReviewPartialMessage(4), '4문제 풀었어요');
  });
}
