// 구독으로 받은 패롯(subParrots)을 앱이 어떻게 보여 주는지.
//
// 서버는 쓸 때 구독 패롯부터 깎는다. 그래서 '지금 쓸 수 있는 양'은 둘의 합이고,
// 환전은 보통 패롯만 된다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/data/models/user.dart';

void main() {
  test('쓸 수 있는 패롯은 보통 패롯과 구독 패롯의 합이다', () {
    const user = AppUser(id: 'u1', parrots: 12, subParrots: 100);

    expect(user.spendableParrots, 112);
    expect(user.coins, 112, reason: '쓸 수 있는지 보는 자리도 같은 값을 본다');
    expect(user.parrots, 12, reason: '환전에 쓰는 값은 보통 패롯 그대로');
  });

  test('구독이 없으면 예전과 같다', () {
    const user = AppUser(id: 'u1', parrots: 7);

    expect(user.subParrots, 0);
    expect(user.spendableParrots, 7);
    expect(user.coins, 7);
  });

  test('서버 값을 읽고 쓸 때 구독 패롯이 빠지지 않는다', () {
    final user = AppUser.fromJson(const {
      'id': 'u1',
      'parrots': 5,
      'crackers': 10,
      'subParrots': 40,
    });

    expect(user.subParrots, 40);
    expect(user.toJson()['subParrots'], 40);
    expect(user.copyWith(subParrots: 0).subParrots, 0);
    expect(user.copyWith(parrots: 9).subParrots, 40, reason: '다른 값만 바꿔도 남는다');
  });

  test('예전 문서처럼 칸이 없으면 0으로 읽는다', () {
    final user = AppUser.fromJson(const {'id': 'u1', 'parrots': 3});

    expect(user.subParrots, 0);
    expect(user.spendableParrots, 3);
  });
}
