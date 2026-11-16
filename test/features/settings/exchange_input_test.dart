// 환전소 입력 규칙(5차 365에 보강).
//
// 누를 때 보는 규칙과 칸 아래 안내가 따로 적혀 있어 말이 달랐다. 이제
// 환전 버튼도 exchangeInputProblem 하나만 본다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/exchange_screen.dart';

void main() {
  String? problem(bool p2c, int amount, int balance) => exchangeInputProblem(
      parrotsToCrackers: p2c, amount: amount, balance: balance);

  test('넣는 동안 환전할 수 없는 이유를 알려준다', () {
    expect(problem(true, 10, 4), '가진 패롯보다 많아요 (보유 4)');
    expect(problem(false, 50000, 44900), '가진 크래커보다 많아요 (보유 44,900)');
    expect(problem(false, 1500, 44900), '크래커는 1,000개 단위로 바꿀 수 있어요');
  });

  test('바꿀 수 있으면 문제가 없다', () {
    expect(problem(true, 4, 4), isNull);
    expect(problem(false, 44000, 44900), isNull);
    expect(problem(true, 0, 0), isNull);
  });

  test('패롯은 1개 단위라 나머지를 따지지 않는다', () {
    expect(problem(true, 3, 10), isNull);
  });

  test('딱 1,000개와 가진 만큼은 바꿀 수 있다', () {
    expect(problem(false, 1000, 1000), isNull);
  });

  test('환전 버튼도 같은 규칙만 본다', () {
    final code =
        File('lib/features/settings/more/presentation/exchange_screen.dart')
            .readAsStringSync();
    // 누를 때 쓰던 두 번째 규칙(다른 말, 따로 적은 1000)이 남아 있으면 안 된다.
    expect(code.contains('가진 패롯이 모자라요'), isFalse);
    expect(code.contains('가진 크래커가 모자라요'), isFalse);
    expect(code.contains('% 1000'), isFalse);
    expect(code.contains('amount * 1000'), isFalse);
  });

  test('끝낸 뒤 안내도 앱 말투', () {
    final code =
        File('lib/features/settings/more/presentation/exchange_screen.dart')
            .readAsStringSync();
    expect(code, contains("showToast('환전했어요.')"));
    expect(code.contains('완료되었습니다'), isFalse);
  });
}
