import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/sections/ad_reward_button.dart';

void main() {
  AdRewardButtonState state(
          {bool cooldown = false, bool ready = false, bool failed = false}) =>
      adRewardButtonState(cooldown: cooldown, ready: ready, failed: failed);

  test('불러오기에 실패하면 계속 도는 대신 다시 불러오기가 된다', () {
    expect(state(failed: true), AdRewardButtonState.failed);
    expect(adRewardButtonLabel(AdRewardButtonState.failed, coins: 3),
        '광고 다시 불러오기');
  });

  test('쿨다운이 가장 먼저, 그다음 준비됨, 실패, 준비 중 순이다', () {
    expect(state(cooldown: true, ready: true), AdRewardButtonState.cooldown);
    expect(state(ready: true, failed: true), AdRewardButtonState.ready);
    expect(state(), AdRewardButtonState.loading);
  });

  test('준비된 버튼은 무엇을 받는지 말한다', () {
    expect(adRewardButtonLabel(AdRewardButtonState.ready, coins: 3),
        '광고 보고 패롯 +3');
    expect(
        adRewardButtonLabel(AdRewardButtonState.cooldown,
            coins: 3, cooldownText: '2분 59초 후 가능'),
        '2분 59초 후 가능');
  });
}
