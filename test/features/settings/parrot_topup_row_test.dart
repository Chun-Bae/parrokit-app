// 패롯도 파는 것이라 '상품' 칸에 줄이 있어야 한다(5차 466).
//
// 464에서 지갑 카드에 '충전' 버튼만 넣었더니, 구독·광고 제거는 줄로
// 있는데 패롯만 빠져 상품 칸만 보면 살 수 있는 줄 몰랐다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/sections/parrot_topup_section.dart';

void main() {
  test('더보기 상품 칸이 세 줄을 다 담는다', () {
    final src = File('lib/features/settings/more/presentation/more_screen.dart')
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    final order = [
      src.indexOf("_GroupLabel('상품')"),
      src.indexOf('SubscriptionSection()'),
      src.indexOf('AdsRemovalSection()'),
      src.indexOf('ParrotTopupSection()'),
    ];
    for (final at in order) {
      expect(at, greaterThan(-1));
    }
    expect(order, orderedEquals(List.of(order)..sort()),
        reason: '상품 칸 바로 아래에 세 줄이 차례로 와야 한다');
  });

  test('패롯 충전 줄이 광고로도 받을 수 있다고 말한다', () {
    // 사는 길만 보여 주면 공짜로 받는 길을 모르고 지나간다.
    expect(parrotTopupSubtitle, contains('광고'));
  });
}
