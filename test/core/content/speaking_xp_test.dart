import 'package:flutter_test/flutter_test.dart';

import 'package:parrokit/core/content/speaking_xp.dart';

void main() {
  test('10 XP마다 레벨이 오르고 0 XP는 Lv.1이다', () {
    expect(speakingLevel(0), 1);
    expect(speakingLevel(9.99), 1);
    expect(speakingLevel(10), 2);
    expect(speakingLevel(19.9), 2);
    expect(speakingLevel(20), 3);
    // 저장이 깨져 음수가 들어와도 Lv.1로 둔다.
    expect(speakingLevel(-5), 1);
  });

  test('이번 단계에서 쌓은 XP는 0 이상 10 미만이다', () {
    expect(xpInLevel(0), 0);
    expect(xpInLevel(9.99), closeTo(9.99, 0.0001));
    expect(xpInLevel(10), 0);
    expect(xpInLevel(12.5), closeTo(2.5, 0.0001));
    expect(xpInLevel(-3), 0);
  });

  test('점수만큼 XP를 주되 최소·최대가 있다', () {
    expect(xpGain(1.0), 1.0);
    expect(xpGain(0.62), closeTo(0.62, 0.0001));
    // 점수가 없거나 0에 가까워도 최소는 준다.
    expect(xpGain(null), minXpGain);
    expect(xpGain(0), minXpGain);
    expect(xpGain(0.05), minXpGain);
    // 1보다 큰 점수가 들어와도 1 XP를 넘지 않는다.
    expect(xpGain(1.4), 1.0);
  });

  test('저장할 XP는 소수 둘째 자리까지만 남긴다', () {
    expect(nextXp(0, 0.1), 0.1);
    expect(nextXp(0.1, 0.624), 0.72);
    expect(nextXp(9.9, 0.1), 10);
    expect(nextXp(-5, 0.5), 0.5);
  });

  test('XP 글자는 소수 첫째 자리까지만 보인다', () {
    expect(xpText(4), '4');
    expect(xpText(3.5), '3.5');
    expect(xpText(3.04), '3');
    expect(xpText(0), '0');
  });

  test("한 단계를 다 채우기 전에는 '10 / 10 XP'로 보이지 않는다", () {
    // 전에는 반올림이라 9.99가 '10'이 됐다. 레벨은 아직 안 올랐는데
    // 화면에는 10 / 10 XP로 보였다(5차).
    expect(xpProgressText(9.99), '9.9');
    expect(xpProgressText(9.96), '9.9');
    expect(speakingLevel(9.99), 1);

    expect(xpProgressText(10), '0');
    expect(xpProgressText(12.5), '2.5');
    expect(xpProgressText(0), '0');
  });
}
