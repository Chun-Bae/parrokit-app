import 'dart:io';
// 환전소 빠른 수량 칩. 가진 것보다 많으면 왜 못 누르는지 말해 준다(5차).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/exchange_quick_amount.dart';

void main() {
  _josaTests();
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

// 조사를 제 셈으로 붙이던 것을 공용 korean_josa로 모았다(5차 486).
//
// 한글이 아닌 글자로 끝나는 이름에서 갈라져 있었다. 공용 쪽은 읽는 소리를
// 알 수 없어 '이(가)'라고 적는데, 환전소만 '이'라고 단정했다.
void _josaTests() {
  group('조사는 공용 셈을 쓴다', () {
    test('받침에 맞춰 붙인다', () {
      expect(quickStepBlockedReason(unit: '패롯', balance: 4, step: 5),
          startsWith('패롯이 '));
      expect(quickStepBlockedReason(unit: '크래커', balance: 900, step: 1000),
          startsWith('크래커가 '));
      expect(quickAllBlockedReason(unit: '크래커', balance: 900, unitSize: 1000),
          startsWith('크래커는 '));
    });

    test('한글이 아닌 이름은 두 가지를 함께 쓴다', () {
      expect(quickStepBlockedReason(unit: 'coin', balance: 1, step: 5),
          startsWith('coin이(가) '));
      expect(quickAllBlockedReason(unit: 'coin', balance: 0, unitSize: 1),
          '바꿀 coin이(가) 없어요.');
    });

    test('이 파일은 조사 셈을 따로 들고 있지 않다', () {
      final code = File('lib/features/settings/more/presentation/'
              'exchange_quick_amount.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('0xAC00'), isFalse);
      expect(code, contains("import 'package:parrokit/core/shared/utils/korean_josa.dart'"));
    });
  });

  // 칩은 적어 둔 수에 더한다(5차 566, 사용자 요청). 막혔는지도 더한
  // 뒤로 따져야 한다 - 5를 두 번 눌러 10이 되는데 가진 게 7이면 막는다.
  group('칩을 더할 때', () {
    test('더한 수가 가진 것보다 많으면 막는다', () {
      expect(
        quickStepBlockedReason(
            unit: '패롯', balance: 7, step: 5, current: 5),
        isNotNull,
      );
    });

    test('더해도 가진 것 안이면 열어 둔다', () {
      expect(
        quickStepBlockedReason(
            unit: '패롯', balance: 7, step: 5, current: 2),
        isNull,
      );
    });

    test('아직 아무것도 안 적었으면 전과 같다', () {
      expect(
        quickStepBlockedReason(unit: '패롯', balance: 3, step: 5),
        quickStepBlockedReason(
            unit: '패롯', balance: 3, step: 5, current: 0),
      );
    });

    test('막힌 까닭에 더한 수를 적는다', () {
      expect(
        quickStepBlockedReason(
            unit: '크래커', balance: 1000, step: 1000, current: 1000),
        contains('2,000'),
      );
    });
  });
}
