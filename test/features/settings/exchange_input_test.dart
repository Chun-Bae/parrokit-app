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
}
