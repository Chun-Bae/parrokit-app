// 패롯으로 산 예문 몫(5차 532).
//
// 하루 한도는 날마다 새로 차고(타이머), 산 몫은 사라지지 않는다.
// 값과 글귀는 서버 exampleQuota.ts의 EXAMPLE_CREDIT_PACK과 같아야 한다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/example_credits.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/example_count_sheet.dart';

void main() {
  test('묶음 값이 서버와 같다', () {
    final ts = File('functions/src/exampleQuota.ts').readAsStringSync();
    final block =
        RegExp(r'EXAMPLE_CREDIT_PACK\s*=\s*\{([^}]*)\}').firstMatch(ts);
    expect(block, isNotNull, reason: '서버 쪽 묶음 값을 찾지 못했다');
    final body = block!.group(1)!;

    int serverValue(String key) =>
        int.parse(RegExp('$key:' r'\s*(\d+)').firstMatch(body)!.group(1)!);

    expect(exampleCreditPackParrots, serverValue('parrots'));
    expect(exampleCreditPackCredits, serverValue('credits'));
  });

  test('묶음 수만큼 값과 몫이 늘어난다', () {
    expect(exampleCreditCost(1), 3);
    expect(exampleCreditGain(1), 10);
    expect(exampleCreditCost(3), 9);
    expect(exampleCreditGain(3), 30);
  });

  group('살 수 있는지', () {
    test('패롯이 넉넉하면 막지 않는다', () {
      expect(exampleCreditBlocked(parrots: 3), isNull);
      expect(exampleCreditBlocked(parrots: 100), isNull);
    });

    test('모자라면 얼마가 모자란지 적는다', () {
      final blocked = exampleCreditBlocked(parrots: 1);
      expect(blocked, isNotNull);
      expect(blocked, contains('2개 모자라요'));
      expect(blocked, contains('1개 있어요'));
    });

    test('잔액을 모르면 막지 않는다', () {
      // 아직 못 읽었을 뿐이다. 서버가 모자라면 그때 거절한다.
      expect(exampleCreditBlocked(parrots: null), isNull);
    });
  });

  // remainingToday에는 산 몫이 이미 더해져 온다. 통째로 '오늘 N개'라고
  // 적으면 거짓말이다 - 산 몫은 내일도 쓸 수 있다.
  group('남은 수 적기', () {
    test('산 몫이 없으면 오늘 치만 적는다', () {
      expect(exampleRoomLine(7, 0), ' 오늘 7개 더 만들 수 있어요.');
      expect(exampleRoomLine(7, null), ' 오늘 7개 더 만들 수 있어요.');
    });

    test('둘 다 있으면 나눠 적는다', () {
      expect(exampleRoomLine(27, 20), ' 오늘 7개와 사 둔 20개를 쓸 수 있어요.');
    });

    test('오늘 치를 다 썼으면 산 몫만 적는다', () {
      expect(exampleRoomLine(20, 20), ' 사 둔 20개를 쓸 수 있어요.');
    });

    test('모르면 아무 말도 하지 않는다', () {
      expect(exampleRoomLine(null, 5), '');
    });
  });

  // 뜻·발음 몫도 같은 틀이다. 단위만 '횟수'이고 한 묶음이 5번이다(5차 535).
  group('뜻·발음 묶음', () {
    test('값이 서버와 같다', () {
      final ts = File('functions/src/exampleQuota.ts').readAsStringSync();
      final block =
          RegExp(r'ASSIST_CREDIT_PACK\s*=\s*\{([^}]*)\}').firstMatch(ts);
      expect(block, isNotNull, reason: '서버 쪽 묶음 값을 찾지 못했다');
      final body = block!.group(1)!;

      int serverValue(String key) =>
          int.parse(RegExp('$key:' r'\s*(\d+)').firstMatch(body)!.group(1)!);

      expect(assistCreditPackParrots, serverValue('parrots'));
      expect(assistCreditPackCredits, serverValue('credits'));
    });

    test('예문과 같은 패롯에 절반을 준다', () {
      expect(assistCreditPackParrots, exampleCreditPackParrots);
      expect(assistCreditGain(1) * 2, exampleCreditGain(1));
    });

    // 두 단추를 가로로 두면서 글을 줄였다(5차 536). 값은 둘 다 같은
    // 3패롯이라 단추마다 되풀이하지 않고 안내 줄에 한 번만 적는다.
    test('단추 글은 짧고 단위를 가린다', () {
      // 단추가 좁아 '생성'은 떼고 주어만 쓴다(5차 562).
      // 단추 안에는 숫자만. 무엇을 사는지는 옆 그림이 말한다
      // (5차 567, 사용자 요청 - 실기기에서 글씨가 잘렸다).
      expect(assistCreditBuyLabel(1), '+5');
      expect(exampleCreditBuyLabel(1), '+10');
      // 읽어 주는 쪽에는 이름까지 그대로 준다.
      expect(assistCreditBuySemantics(1), '뜻·발음·원문 +5번');
      expect(exampleCreditBuySemantics(1), '예문 +10번');
      // 값이 어디에도 없으면 안 된다.
      expect(creditPackPriceHint(1), '한 묶음에 패롯 3개예요.');
    });

    test('패롯이 모자라면 막는다', () {
      expect(assistCreditBlocked(parrots: 3), isNull);
      expect(assistCreditBlocked(parrots: 2), contains('1개 모자라요'));
    });
  });
}
