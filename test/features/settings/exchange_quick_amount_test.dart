// 환전소 빠른 수량 칩. 가진 것보다 많으면 왜 못 누르는지 말해 준다(5차).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/exchange_quick_amount.dart';

void main() {
  group('정해진 수량 칩', () {
    test('가진 만큼이면 막지 않는다', () {
      expect(quickStepBlockedReason(unit: '패롯', balance: 5, step: 5), isNull);
      expect(quickStepBlockedReason(unit: '패롯', balance: 9, step: 5), isNull);
    });

    test('모자라면 지금 가진 수와 함께 알려 준다', () {
      expect(
        quickStepBlockedReason(unit: '패롯', balance: 4, step: 5),
        '패롯이 4개뿐이라 5개는 못 바꿔요.',
      );
      // 조사도 말에 맞춘다(패롯이 / 크래커가).
      expect(
        quickStepBlockedReason(unit: '크래커', balance: 900, step: 1000),
        '크래커가 900개뿐이라 1,000개는 못 바꿔요.',
      );
    });
  });

  group("'전부' 칩", () {
    test('바꿀 것이 있으면 막지 않는다', () {
      expect(quickAllBlockedReason(unit: '패롯', balance: 4, unitSize: 1),
          isNull);
      expect(
          quickAllBlockedReason(unit: '크래커', balance: 1200, unitSize: 1000),
          isNull);
    });

    test('하나도 없으면 그렇게 말한다', () {
      expect(quickAllBlockedReason(unit: '패롯', balance: 0, unitSize: 1),
          '바꿀 패롯이 없어요.');
      expect(quickAllBlockedReason(unit: '크래커', balance: 0, unitSize: 1000),
          '바꿀 크래커가 없어요.');
    });

    test('단위보다 적으면 단위를 알려 준다', () {
      expect(
        quickAllBlockedReason(unit: '크래커', balance: 900, unitSize: 1000),
        '크래커는 1,000개 단위로 바꿔요. 지금은 900개예요.',
      );
    });
  });
}
